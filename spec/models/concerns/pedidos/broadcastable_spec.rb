require 'rails_helper'

RSpec.describe Pedidos::Broadcastable do
  let(:dummy_class) do
    Class.new do
      include Pedidos::Broadcastable

      attr_accessor :fecha, :tienda_id, :persisted_value

      def persisted?
        persisted_value
      end
    end
  end

  let(:instance) { dummy_class.new }

  before do
    instance.fecha = Date.current
    instance.tienda_id = 1
    instance.persisted_value = true
    allow(RedisServiceClient).to receive(:setex)
    allow(RedisServiceClient).to receive_messages(throttled?: false, get: nil)
    allow(RedisServiceClient).to receive(:del)
    allow(ActionCable).to receive_message_chain(:server, :broadcast)
    pedido_relation = double('Relation')
    allow(pedido_relation).to receive_messages(where: pedido_relation, count: 0)
    allow(Pedidos::Pedido).to receive(:where).and_return(pedido_relation)
  end

  describe '#broadcast_daily_orders_update' do
    it 'does not broadcast when fecha is not today' do
      instance.fecha = Date.yesterday
      expect(ActionCable.server).not_to receive(:broadcast)
      instance.send(:broadcast_daily_orders_update)
    end

    it 'schedules delayed broadcast when throttled' do
      allow(RedisServiceClient).to receive(:throttled?).and_return(true)
      expect(instance).to receive(:schedule_delayed_broadcast)
      instance.send(:broadcast_daily_orders_update)
    end
  end
end
