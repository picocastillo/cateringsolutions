class RedisServiceClient
  include Singleton

  def initialize
    @redis = Redis.new(
      host: ENV['REDIS_HOST'] || 'localhost',
      port: ENV['REDIS_PORT'] || 6379,
      db: ENV['REDIS_DB'] || 0,
      timeout: 5,
      reconnect_attempts: 3
    )
  end

  def self.instance
    @instance ||= new
  end

  def self.redis
    instance.redis
  end

  def self.ping
    instance.ping
  end

  def self.throttled?(key)
    instance.throttled?(key)
  end

  attr_reader :redis

  def self.get(key)
    instance.get(key)
  end

  # Convenience methods for common Redis operations with auto-reconnection
  def get(key)
    with_reconnection { redis.get(key) }
  end

  def self.set(key, value, options = {})
    instance.set(key, value, options)
  end

  def set(key, value, options = {})
    with_reconnection do
      if options[:expires_in]
        redis.setex(key, options[:expires_in], value)
      else
        redis.set(key, value)
      end
    end
  end

  def self.setex(key, seconds, value)
    instance.setex(key, seconds, value)
  end

  def setex(key, seconds, value)
    with_reconnection { redis.setex(key, seconds, value) }
  end

  def self.del(key)
    instance.del(key)
  end

  def del(key)
    with_reconnection { redis.del(key) }
  end

  def exists?(key)
    with_reconnection { redis.exists?(key) }
  end

  def expire(key, seconds)
    with_reconnection { redis.expire(key, seconds) }
  end

  def ttl(key)
    with_reconnection { redis.ttl(key) }
  end

  # Throttling helper methods
  def throttle(key, duration_seconds, &block)
    return false if get(key)

    setex(key, duration_seconds, Time.current.to_i)
    block.call if block_given?
    true
  end

  def throttled?(key)
    exists?(key)
  end

  # Connection health check
  def ping
    with_reconnection { redis.ping == 'PONG' }
  rescue StandardError => e
    Rails.logger.error "Redis ping failed after retries: #{e.message}"
    false
  end

  # Graceful disconnect
  def disconnect
    redis.disconnect!
  rescue StandardError => e
    Rails.logger.error "Redis disconnect failed: #{e.message}"
  end

  private

  # Execute Redis commands with automatic reconnection on failure
  def with_reconnection(max_retries: 3)
    retries = 0
    begin
      yield
    rescue Redis::ConnectionError, Redis::CannotConnectError, Errno::ECONNREFUSED => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "Redis connection lost (attempt #{retries}/#{max_retries}): #{e.message}"
        sleep(0.5 * retries) # Exponential backoff: 0.5s, 1s, 1.5s
        reconnect
        retry
      else
        Rails.logger.error "Redis connection failed after #{max_retries} retries: #{e.message}"
        raise e
      end
    rescue StandardError => e
      Rails.logger.error "Redis operation failed: #{e.message}"
      raise e
    end
  end

  # Reconnect logic for connection failures
  def reconnect
    Rails.logger.info 'Attempting to reconnect to Redis...'
    @redis = Redis.new(
      host: ENV['REDIS_HOST'] || 'localhost',
      port: ENV['REDIS_PORT'] || 6379,
      db: ENV['REDIS_DB'] || 0,
      timeout: 5,
      reconnect_attempts: 1 # We handle retries manually in with_reconnection
    )
    Rails.logger.info '✅ Redis reconnection successful'
  rescue StandardError => e
    Rails.logger.error "❌ Redis reconnection failed: #{e.message}"
    raise e
  end
end
