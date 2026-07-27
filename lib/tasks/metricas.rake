namespace :metricas do
  desc 'Collect daily metrics from yesterday\'s logs and DB stats'
  task daily: :environment do
    fecha = Date.yesterday
    puts "=== Métricas diarias para #{fecha} ==="

    # Parse logs for yesterday (returns { nil => global, tienda_id => per_tienda, ... })
    parsed = Metricas::LogParser.new(fecha).parse
    global_data = parsed.delete(nil)
    errors = global_data.delete(:errors) || []
    puts "  Requests: #{global_data[:total_requests]}, Mobile: #{global_data[:requests_mobile]}, Desktop: #{global_data[:requests_desktop]}"
    puts "  Avg response: #{global_data[:avg_response_time_ms]}ms, P95: #{global_data[:p95_response_time_ms]}ms"
    puts "  2xx: #{global_data[:status_2xx]}, 3xx: #{global_data[:status_3xx]}, 4xx: #{global_data[:status_4xx]}, 5xx: #{global_data[:status_5xx]}"

    # Collect DB stats
    db_data = Metricas::DbAnalyzer.collect
    puts "  DB size: #{db_data[:db_total_size_mb]}MB, Connections: #{db_data[:db_active_connections]}/#{db_data[:db_max_connections]}"

    # Save global snapshot (tienda_id = nil)
    snapshot = Metricas::Snapshot.find_or_initialize_by(fecha: fecha, tienda_id: nil)
    snapshot.assign_attributes(global_data.merge(db_data))
    snapshot.save!
    puts "  Global snapshot saved (id: #{snapshot.id})"

    # Save per-tienda snapshots
    parsed.each do |tienda_id, tienda_data|
      tienda_data.delete(:errors) # Errors only stored globally
      ts = Metricas::Snapshot.find_or_initialize_by(fecha: fecha, tienda_id: tienda_id)
      ts.assign_attributes(tienda_data)
      ts.save!
    end
    puts "  #{parsed.size} tienda snapshots saved" if parsed.any?

    # Save errors
    if errors.present?
      errors.each do |err|
        Metricas::ErrorEntry.create!(err)
      end
      puts "  #{errors.size} errors recorded"
    end

    # Cleanup old errors (keep last 90 days)
    deleted = Metricas::ErrorEntry.where(fecha: ...90.days.ago).delete_all
    puts "  Cleaned up #{deleted} old error entries" if deleted.positive?

    puts '=== Completado ==='
  end

  desc 'Backfill metrics from rotated log files (default: 20 days)'
  task :backfill, [:days] => :environment do |_t, args|
    days = (args[:days] || 20).to_i
    puts "=== Backfill de métricas (#{days} días) ==="

    cutoff = (Time.zone.today - days - 2).to_time
    log_files = Metricas::LogParser.available_log_files.select { |f| File.mtime(f) > cutoff }
    puts "  Log files a procesar: #{log_files.size}"

    # Collect data from relevant files first, merging dates that span multiple files
    all_dates = {}
    log_files.each do |file|
      puts "  Procesando: #{File.basename(file)}..."
      dates_in_file = Metricas::LogParser.parse_file_raw(file)

      dates_in_file.each do |fecha, log_data|
        if all_dates[fecha]
          Metricas::LogParser.merge_data(all_dates[fecha], log_data)
        else
          all_dates[fecha] = log_data
        end
      end
    end

    # Finalize and save snapshots, most recent first (skip today — day not complete)
    dates_processed = 0
    all_dates.keys.sort.reverse.each do |fecha|
      break if dates_processed >= days
      next if fecha >= Time.zone.today

      raw_data = all_dates[fecha]
      global_data = Metricas::LogParser.finalize_class(raw_data)
      errors = global_data.delete(:errors) || []

      # Save global snapshot
      snapshot = Metricas::Snapshot.find_or_initialize_by(fecha: fecha, tienda_id: nil)
      snapshot.assign_attributes(global_data)
      snapshot.save!
      dates_processed += 1
      puts "    #{fecha}: #{global_data[:total_requests]} requests"

      # Save per-tienda snapshots
      raw_data[:by_tienda].each do |tienda_id, tdata|
        tienda_finalized = Metricas::LogParser.finalize_class(tdata)
        tienda_finalized.delete(:errors)
        ts = Metricas::Snapshot.find_or_initialize_by(fecha: fecha, tienda_id: tienda_id)
        ts.assign_attributes(tienda_finalized)
        ts.save!
      end

      # Save errors from backfill
      next if errors.blank?

      Metricas::ErrorEntry.where(fecha: fecha.all_day).delete_all
      errors.first(50).each do |err|
        Metricas::ErrorEntry.create!(err)
      end
    end

    puts "=== Backfill completado: #{dates_processed} días procesados ==="
  end
end
