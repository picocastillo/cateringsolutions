require 'rails_helper'

RSpec.describe RedisServiceClient do
  let(:client) { described_class.instance }

  after do
    client.redis.flushdb
  end

  describe '.instance' do
    it 'returns singleton instance' do
      expect(described_class.instance).to eq(described_class.instance)
    end
  end

  describe '#redis' do
    it 'returns redis connection' do
      expect(client.redis).to be_a(Redis)
    end
  end

  describe '#get' do
    it 'gets value from redis' do
      client.set('test_key', 'test_value')
      expect(client.get('test_key')).to eq('test_value')
    end
  end

  describe '#set' do
    it 'sets value in redis' do
      client.set('test_key', 'test_value')
      expect(client.get('test_key')).to eq('test_value')
    end

    it 'sets value with expiration' do
      client.set('test_key', 'test_value', expires_in: 1)
      expect(client.ttl('test_key')).to be > 0
    end
  end

  describe '#setex' do
    it 'sets value with expiration' do
      client.setex('test_key', 10, 'test_value')
      expect(client.get('test_key')).to eq('test_value')
      expect(client.ttl('test_key')).to be > 0
    end
  end

  describe '#del' do
    it 'deletes key from redis' do
      client.set('test_key', 'test_value')
      client.del('test_key')
      expect(client.get('test_key')).to be_nil
    end
  end

  describe '#exists?' do
    it 'returns true when key exists' do
      client.set('test_key', 'test_value')
      expect(client.exists?('test_key')).to be true
    end

    it 'returns false when key does not exist' do
      expect(client.exists?('nonexistent_key')).to be false
    end
  end

  describe '#expire' do
    it 'sets expiration on key' do
      client.set('test_key', 'test_value')
      client.expire('test_key', 10)
      expect(client.ttl('test_key')).to be > 0
    end
  end

  describe '#throttle' do
    it 'returns true on first call' do
      expect(client.throttle('throttle_key', 1)).to be true
    end

    it 'returns false on subsequent calls' do
      client.throttle('throttle_key', 10)
      expect(client.throttle('throttle_key', 10)).to be false
    end

    it 'calls block when successful' do
      called = false
      client.throttle('throttle_key2', 1) { called = true }
      expect(called).to be true
    end
  end

  describe '#throttled?' do
    it 'returns true when throttled' do
      client.setex('throttle_key', 10, 'value')
      expect(client.throttled?('throttle_key')).to be true
    end

    it 'returns false when not throttled' do
      expect(client.throttled?('nonexistent_key')).to be false
    end
  end

  describe '#ping' do
    it 'returns true when connected' do
      expect(client.ping).to be true
    end
  end
end
