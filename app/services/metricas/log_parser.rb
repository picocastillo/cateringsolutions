module Metricas
  class LogParser
    # Extracts request UUID from tagged log lines: [c7d8433e-c7db-44b4-b960-13271d23781f]
    UUID_REGEX = /\[([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\]/i

    # Matches: Started GET "/path" for 1.2.3.4 at DD/MM/YYYY HH:MM
    # Also supports legacy: Started GET "/path" for 1.2.3.4 at YYYY-MM-DD HH:MM:SS
    STARTED_REGEX = %r{
      Started\s+(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+"([^"]+)"\s+
      for\s+([\d.]+)\s+at\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}|\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})
    }x

    # Matches: Completed 200 OK in 45ms (Views: 30.1ms | ActiveRecord: 10.2ms)
    COMPLETED_REGEX = /Completed\s+(\d{3})\s+.*?in\s+([\d.]+)ms/

    # Matches: [METRICS] ip=1.2.3.4 mobile=true tienda_id=5 usuario_id=42 (tienda_id/usuario_id optional for backward compat)
    METRICS_REGEX = /\[METRICS\]\s+ip=([\d.]+)\s+mobile=(true|false)(?:\s+tienda_id=(\d+))?(?:\s+usuario_id=(\d+))?/

    # Matches: Processing by SomeController#action as HTML
    PROCESSING_REGEX = /Processing\s+by\s+(\S+#\S+)/

    # Matches error/exception lines (anchored after log prefix to avoid matching SQL debug lines)
    ERROR_REGEX = /\]\s+(?:ERROR|FATAL)\s+--\s+:.*?(\w+(?:::\w+)*(?:Error|Exception|Fault))\s*[(:]?\s*(.*)/

    # Matches FATAL log lines
    FATAL_REGEX = /^F,\s+\[(\d{4}-\d{2}-\d{2}).*?\]\s+FATAL\s+--\s+:\s+(.*)/

    # Matches: Job Pedidos::MercadopagoUpdaterJob [...] (queue=fast) COMPLETED after 1.3613
    DJ_COMPLETED_REGEX = /Job\s+(\S+)\s+\[.*?\].*?\(queue=(\w+)\)\s+COMPLETED\s+after\s+([\d.]+)/

    # Matches date from DJ log lines: 2026-02-11T07:20:34-0300:
    DJ_DATE_REGEX = /(\d{4}-\d{2}-\d{2})T/

    def initialize(target_date)
      @target_date = target_date
      @date_str = target_date.strftime('%Y-%m-%d')
    end

    # Normalizes date from DD/MM/YYYY or YYYY-MM-DD to YYYY-MM-DD
    def self.normalize_date_str(raw)
      date_part = raw.split.first
      if date_part.include?('/')
        # DD/MM/YYYY → YYYY-MM-DD
        parts = date_part.split('/')
        "#{parts[2]}-#{parts[1]}-#{parts[0]}"
      else
        date_part[0..9]
      end
    end

    # Parses a timestamp from either DD/MM/YYYY HH:MM or YYYY-MM-DD HH:MM:SS format
    def self.parse_time(raw)
      normalized = if raw.include?('/')
                     date_part, time_part = raw.split(' ', 2)
                     parts = date_part.split('/')
                     "#{parts[2]}-#{parts[1]}-#{parts[0]} #{time_part}"
                   else
                     raw
                   end
      Time.zone.parse(normalized)
    rescue StandardError
      Time.current
    end

    def parse
      data = empty_data
      log_files = self.class.files_for_date(@target_date)

      log_files.each do |file|
        parse_file_for_date(file, data)
      end

      # Return global + per-tienda finalized data
      result = { nil => finalize(data) }
      data[:by_tienda].each do |tid, tdata|
        result[tid] = self.class.finalize_class(tdata)
      end
      result
    end

    def self.available_log_files
      log_dir = log_directory
      files = []

      # Plain log files
      Dir.glob(File.join(log_dir, "#{log_prefix}.log*")).each do |f|
        next if f.end_with?('.gz')

        files << f
      end

      # Gzipped log files
      Dir.glob(File.join(log_dir, "#{log_prefix}.log.*.gz")).each do |f|
        files << f
      end

      # Sort: current log first, then by number
      files.sort_by do |f|
        name = File.basename(f)
        num = name[/\.(\d+)/, 1]
        num ? num.to_i : -1
      end
    end

    def self.parse_file_raw(file_path)
      dates = Hash.new { |h, k| h[k] = empty_data_class }
      inflight = {} # uuid => request hash

      each_line(file_path) do |line|
        uuid = line[UUID_REGEX, 1]

        if (m = line.match(STARTED_REGEX))
          if uuid
            date_str = normalize_date_str(m[4])
            inflight[uuid] = {
              method: m[1], path: m[2], ip: m[3],
              date: date_str, time: m[4]
            }
            # Prevent unbounded memory growth from incomplete requests
            cleanup_inflight(inflight) if inflight.size > 500
          end
        elsif (m = line.match(PROCESSING_REGEX))
          inflight[uuid][:controller_action] = m[1] if uuid && inflight[uuid]
        elsif (m = line.match(METRICS_REGEX))
          if uuid && inflight[uuid]
            inflight[uuid][:mobile] = (m[2] == 'true')
            tid = m[3]&.to_i
            inflight[uuid][:tienda_id] = tid if tid
            uid = m[4]&.to_i
            inflight[uuid][:usuario_id] = uid if uid
          end
        elsif (m = line.match(COMPLETED_REGEX))
          req = uuid ? inflight.delete(uuid) : nil
          next unless req

          date_str = req[:date]
          next unless date_str

          fecha = begin
            Date.parse(date_str)
          rescue StandardError
            next
          end
          d = dates[fecha]
          status = m[1].to_i
          time_ms = m[2].to_f

          record_request(d, req, status, time_ms)
        elsif (m = line.match(ERROR_REGEX))
          req = (uuid && inflight[uuid]) || {}
          date_str = req[:date]
          next unless date_str

          fecha = begin
            Date.parse(date_str)
          rescue StandardError
            next
          end
          d = dates[fecha]
          err_time = parse_time(req[:time] || date_str)
          d[:errors] << {
            fecha: err_time,
            error_class: m[1],
            error_message: m[2].to_s.truncate(500),
            controller_action: req[:controller_action],
            ip: req[:ip],
            url: req[:path]
          }
        elsif (m = line.match(FATAL_REGEX))
          fecha = begin
            Date.parse(m[1])
          rescue StandardError
            next
          end
          d = dates[fecha]
          fatal_time = begin
            Time.zone.parse("#{m[1]} 00:00:00")
          rescue StandardError
            Time.current
          end
          d[:errors] << {
            fecha: fatal_time,
            error_class: 'FATAL',
            error_message: m[2].to_s.truncate(500)
          }
        elsif (m = line.match(DJ_COMPLETED_REGEX))
          # Delayed Job completion line (no UUID — these are background workers)
          date_str = line[DJ_DATE_REGEX, 1] || line[/(\d{4}-\d{2}-\d{2})/, 1]
          next unless date_str

          fecha = begin
            Date.parse(date_str)
          rescue StandardError
            next
          end
          d = dates[fecha]
          record_dj(d, m[1], m[2], m[3].to_f)
        end
      end

      dates
    end

    def self.cleanup_inflight(inflight)
      # Remove oldest half to prevent memory growth from incomplete requests
      keys = inflight.keys.first(inflight.size / 2)
      keys.each { |k| inflight.delete(k) }
    end

    def self.parse_file(file_path)
      raw = parse_file_raw(file_path)
      result = {}
      raw.each do |fecha, d|
        result[fecha] = finalize_class(d)
      end
      result
    end

    def self.files_for_date(target_date)
      # In dev: development.log and development.log.0
      # In prod: production.log, production.log.1, production.log.N.gz
      # We check all files since rotation timing is unpredictable
      available_log_files.select do |f|
        file_might_contain_date?(f, target_date)
      end
    end

    def self.merge_data(target, source)
      target[:total_requests] += source[:total_requests]
      target[:requests_mobile] += source[:requests_mobile]
      target[:requests_desktop] += source[:requests_desktop]
      target[:requests_unknown] += source[:requests_unknown]
      target[:status_2xx] += source[:status_2xx]
      target[:status_3xx] += source[:status_3xx]
      target[:status_4xx] += source[:status_4xx]
      target[:status_5xx] += source[:status_5xx]
      target[:unique_ips].merge(source[:unique_ips])
      target[:response_times].concat(source[:response_times])
      source[:endpoints].each do |k, v|
        target[:endpoints][k][:count] += v[:count]
        target[:endpoints][k][:total_ms] += v[:total_ms]
      end
      source[:ip_counts].each { |ip, count| target[:ip_counts][ip] += count }
      24.times { |h| target[:hourly][h] += source[:hourly][h] }
      target[:errors].concat(source[:errors])
      # Merge worst requests
      target[:worst_requests].concat(source[:worst_requests])
      target[:worst_requests] = target[:worst_requests].sort_by { |r| -r[:time_ms] }.first(20)
      # Merge delayed jobs stats
      source[:dj_stats].each do |key, v|
        t = target[:dj_stats][key]
        t[:count] += v[:count]
        t[:total_seconds] += v[:total_seconds]
        t[:max_seconds] = [t[:max_seconds], v[:max_seconds]].max
      end
      # Merge per-tienda data
      return unless source[:by_tienda] && target[:by_tienda]

      source[:by_tienda].each do |tid, tdata|
        if target[:by_tienda][tid]
          merge_data(target[:by_tienda][tid], tdata)
        else
          target[:by_tienda][tid] = tdata
        end
      end
    end

    private

    def parse_file_for_date(file_path, data)
      inflight = {} # uuid => request hash

      self.class.each_line(file_path) do |line|
        uuid = line[UUID_REGEX, 1]

        if (m = line.match(STARTED_REGEX))
          date_str = self.class.normalize_date_str(m[4])
          if uuid && date_str == @date_str
            inflight[uuid] = { method: m[1], path: m[2], ip: m[3], date: date_str, time: m[4] }
            self.class.cleanup_inflight(inflight) if inflight.size > 500
          end
        elsif uuid && inflight[uuid]
          if (m = line.match(PROCESSING_REGEX))
            inflight[uuid][:controller_action] = m[1]
          elsif (m = line.match(METRICS_REGEX))
            inflight[uuid][:mobile] = (m[2] == 'true')
            tid = m[3]&.to_i
            inflight[uuid][:tienda_id] = tid if tid
            uid = m[4]&.to_i
            inflight[uuid][:usuario_id] = uid if uid
          elsif (m = line.match(COMPLETED_REGEX))
            req = inflight.delete(uuid)
            status = m[1].to_i
            time_ms = m[2].to_f
            self.class.record_request(data, req, status, time_ms)
          elsif (m = line.match(ERROR_REGEX))
            req = inflight[uuid]
            err_time = self.class.parse_time(req[:time] || @date_str)
            data[:errors] << {
              fecha: err_time,
              error_class: m[1],
              error_message: m[2].to_s.truncate(500),
              controller_action: req[:controller_action],
              ip: req[:ip],
              url: req[:path]
            }
          end
        elsif (m = line.match(DJ_COMPLETED_REGEX))
          date_str = line[DJ_DATE_REGEX, 1] || line[/(\d{4}-\d{2}-\d{2})/, 1]
          self.class.record_dj(data, m[1], m[2], m[3].to_f) if date_str == @date_str
        end
      end
    end

    def empty_data
      self.class.empty_data_class
    end

    # rubocop:disable Lint/IneffectiveAccessModifier
    def self.empty_data_class
      {
        total_requests: 0,
        requests_mobile: 0,
        requests_desktop: 0,
        requests_unknown: 0,
        status_2xx: 0, status_3xx: 0, status_4xx: 0, status_5xx: 0,
        unique_ips: Set.new,
        response_times: [],
        worst_requests: [],
        endpoints: Hash.new { |h, k| h[k] = { count: 0, total_ms: 0.0 } },
        ip_counts: Hash.new(0),
        hourly: Array.new(24, 0),
        errors: [],
        dj_stats: Hash.new { |h, k| h[k] = { count: 0, total_seconds: 0.0, max_seconds: 0.0 } },
        by_tienda: Hash.new { |h, k| h[k] = empty_tienda_data }
      }
    end

    def self.empty_tienda_data
      {
        total_requests: 0,
        requests_mobile: 0,
        requests_desktop: 0,
        requests_unknown: 0,
        status_2xx: 0, status_3xx: 0, status_4xx: 0, status_5xx: 0,
        unique_ips: Set.new,
        response_times: [],
        worst_requests: [],
        endpoints: Hash.new { |h, k| h[k] = { count: 0, total_ms: 0.0 } },
        ip_counts: Hash.new(0),
        hourly: Array.new(24, 0),
        errors: [],
        dj_stats: Hash.new { |h, k| h[k] = { count: 0, total_seconds: 0.0, max_seconds: 0.0 } }
      }
    end

    def self.record_request(data, req, status, time_ms)
      record_request_in(data, req, status, time_ms)

      # Also record per-tienda if tienda_id is present and > 0
      tienda_id = req[:tienda_id]
      return unless tienda_id.is_a?(Integer) && tienda_id.positive?

      record_request_in(data[:by_tienda][tienda_id], req, status, time_ms)
    end

    def self.record_request_in(data, req, status, time_ms)
      data[:total_requests] += 1
      data[:response_times] << time_ms

      # Mobile tracking (unknown defaults to desktop)
      if req.key?(:mobile) && req[:mobile]
        data[:requests_mobile] += 1
      else
        data[:requests_desktop] += 1
      end

      # Status codes
      case status
      when 200..299 then data[:status_2xx] += 1
      when 300..399 then data[:status_3xx] += 1
      when 400..499 then data[:status_4xx] += 1
      when 500..599
        data[:status_5xx] += 1
        err_time = parse_time(req[:time] || Time.zone.today.to_s)
        data[:errors] << {
          fecha: err_time,
          error_class: "HTTP #{status}",
          error_message: "#{req[:method]} #{req[:path]}",
          controller_action: req[:controller_action],
          status_code: status,
          ip: req[:ip],
          url: req[:path]
        }
      end

      # IPs
      if req[:ip]
        data[:unique_ips].add(req[:ip])
        data[:ip_counts][req[:ip]] += 1
      end

      # Endpoints
      endpoint = req[:controller_action] || "#{req[:method]} #{req[:path]}"
      data[:endpoints][endpoint][:count] += 1
      data[:endpoints][endpoint][:total_ms] += time_ms

      # Worst response times (keep top 20)
      track_worst_request(data, req, endpoint, time_ms)

      # Hourly distribution
      return unless req[:time]

      hour = req[:time][11..12].to_i
      data[:hourly][hour] += 1 if hour >= 0 && hour < 24
    end

    def self.track_worst_request(data, req, endpoint, time_ms)
      worst = data[:worst_requests]
      return unless worst.size < 20 || time_ms > (worst.last&.dig(:time_ms) || 0)

      worst << { endpoint: endpoint, path: req[:path], time_ms: time_ms, hora: req[:time]&.[](11..15) }
      data[:worst_requests] = worst.sort_by { |r| -r[:time_ms] }.first(20)
    end

    def self.record_dj(data, job_name, queue, seconds)
      # Track by job name
      j = data[:dj_stats][job_name]
      j[:count] += 1
      j[:total_seconds] += seconds
      j[:max_seconds] = seconds if seconds > j[:max_seconds]
      j[:queue] = queue
    end

    def self.finalize_dj_stats(dj_stats)
      dj_stats.map do |job_name, v|
        {
          'job' => job_name,
          'queue' => v[:queue],
          'count' => v[:count],
          'avg_seconds' => (v[:total_seconds] / v[:count]).round(3),
          'max_seconds' => v[:max_seconds].round(3),
          'total_seconds' => v[:total_seconds].round(2)
        }
      end.sort_by { |j| -j['total_seconds'] }
    end

    def finalize(data)
      self.class.finalize_class(data)
    end

    def self.finalize_class(data)
      times = data[:response_times].sort
      total = data[:total_requests]

      avg = total.positive? ? (times.sum / total).round(2) : 0
      p95 = total.positive? ? (times[(total * 0.95).to_i] || times.last || 0).round(2) : 0
      max = times.last&.round(2) || 0

      histogram = {
        'under_100ms' => times.count { |t| t < 100 },
        'under_500ms' => times.count { |t| t >= 100 && t < 500 },
        'under_1s' => times.count { |t| t >= 500 && t < 1000 },
        'under_3s' => times.count { |t| t >= 1000 && t < 3000 },
        'over_3s' => times.count { |t| t >= 3000 }
      }

      top_endpoints = data[:endpoints]
                      .map { |k, v| { 'endpoint' => k, 'count' => v[:count], 'avg_ms' => (v[:total_ms] / v[:count]).round(2) } }
                      .sort_by { |e| -e['count'] }
                      .first(20)

      top_ips = data[:ip_counts]
                .map { |ip, count| { 'ip' => ip, 'count' => count } }
                .sort_by { |e| -e['count'] }
                .first(20)

      worst_response_times = data[:endpoints]
                             .map { |k, v| { 'endpoint' => k, 'count' => v[:count], 'avg_ms' => (v[:total_ms] / v[:count]).round(2) } }
                             .sort_by { |e| -e['avg_ms'] }
                             .first(20)

      {
        total_requests: total,
        requests_mobile: data[:requests_mobile],
        requests_desktop: data[:requests_desktop],
        requests_unknown: data[:requests_unknown],
        avg_response_time_ms: avg,
        p95_response_time_ms: p95,
        max_response_time_ms: max,
        status_2xx: data[:status_2xx],
        status_3xx: data[:status_3xx],
        status_4xx: data[:status_4xx],
        status_5xx: data[:status_5xx],
        unique_ips: data[:unique_ips].size,
        top_endpoints: top_endpoints,
        top_ips: top_ips,
        response_times_histogram: histogram,
        worst_response_times: worst_response_times,
        delayed_jobs_stats: finalize_dj_stats(data[:dj_stats]),
        requests_by_hour: data[:hourly],
        errors: data[:errors]
      }
    end

    def self.each_line(file_path, &)
      if file_path.end_with?('.gz')
        IO.popen(['zcat', file_path]) do |io|
          io.each_line(&)
        end
      else
        File.open(file_path, 'r') do |io|
          io.each_line(&)
        end
      end
    rescue StandardError => e
      Rails.logger.error "Metricas::LogParser error reading #{file_path}: #{e.message}"
    end

    def self.file_might_contain_date?(file_path, target_date)
      # For recent files, just try them all — the parser filters by date internally
      # For efficiency, skip files older than 60 days based on mtime
      return false unless File.exist?(file_path)

      File.mtime(file_path) > (target_date - 2.days).to_time
    rescue StandardError
      true
    end

    def self.log_directory
      log_dir = Rails.root.join('log')
      # In production with Capistrano, logs may be in shared/log
      shared_log = Rails.root.join('../../shared/log')
      if Rails.env.production? && File.directory?(shared_log)
        shared_log
      else
        log_dir
      end
    end

    def self.log_prefix
      Rails.env.production? ? 'production' : 'development'
    end
    # rubocop:enable Lint/IneffectiveAccessModifier
  end
end
