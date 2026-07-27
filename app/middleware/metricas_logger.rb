class MetricasLogger
  MOBILE_REGEX = /Mobile|Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i

  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      ua = env['HTTP_USER_AGENT'].to_s
      forwarded = env['HTTP_X_FORWARDED_FOR']&.split(',')
      ip = forwarded&.first&.strip || env['REMOTE_ADDR'] || '-'
      mobile = ua.match?(MOBILE_REGEX)
      # Store in env for controller to add tienda_id later
      env['metricas.ip'] = ip
      env['metricas.mobile'] = mobile
    rescue StandardError
      # Never break the request for metrics logging
    end

    status, headers, response = @app.call(env)

    # Log metrics AFTER the request only if controller didn't log (fallback)
    unless env['metricas.logged']
      begin
        Rails.logger.info "[METRICS] ip=#{env['metricas.ip'] || '-'} mobile=#{env['metricas.mobile'] || false} tienda_id=0 usuario_id=0"
      rescue StandardError
        # Never break the request for metrics logging
      end
    end

    [status, headers, response]
  end
end
