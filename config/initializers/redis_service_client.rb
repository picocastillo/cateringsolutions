# Redis Service Client Configuration
begin
  # Test Redis connection on initialization
  Rails.logger.debug 'Redis Service Client connection failed - will retry on first use!!!!!!!!!!!!!!!!!!!!!!!' unless RedisServiceClient.ping
rescue StandardError => e
  Rails.logger.debug { "Redis Service Client initialization error: #{e.message}" }
  Rails.logger.debug 'Redis will attempt to reconnect automatically when needed'
end

# Graceful shutdown hook
at_exit do
  RedisServiceClient.instance.disconnect
rescue StandardError => e
  Rails.logger.debug { "Redis Service Client disconnect error: #{e.message}" }
end
