require 'rails_helper'

RSpec.describe Pedidos::PedidoCocina, type: :model do
  let(:tienda) { create(:tienda) }
  let(:autor) { create(:usuario) }

  describe 'associations' do
    it { is_expected.to belong_to(:tienda).class_name('Tiendas::Tienda') }
    it { is_expected.to belong_to(:autor).class_name('Usuarios::Usuario') }
    it { is_expected.to have_many(:pedidos).class_name('Pedidos::Pedido').dependent(:nullify) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:pedidos) }
  end

  describe 'callbacks' do
    describe '#set_codigo' do
      let(:pedido) { create(:pedido, tienda: tienda) }

      it 'sets codigo before validation if blank' do
        pedido_cocina = described_class.new(tienda: tienda, autor: autor)
        pedido_cocina.pedidos = [pedido]
        pedido_cocina.valid?
        expect(pedido_cocina.codigo).to be_present
      end

      it 'does not override existing codigo' do
        pedido_cocina = described_class.new(tienda: tienda, autor: autor, codigo: 99)
        pedido_cocina.pedidos = [pedido]
        pedido_cocina.valid?
        expect(pedido_cocina.codigo).to eq 99
      end

      it 'sets fecha to current time if blank' do
        pedido_cocina = described_class.new(tienda: tienda, autor: autor)
        pedido_cocina.pedidos = [pedido]
        pedido_cocina.valid?
        expect(pedido_cocina.fecha).to be_within(2.seconds).of(Time.zone.now)
      end

      it 'does not override existing fecha' do
        fecha_pasada = 1.day.ago
        pedido_cocina = described_class.new(tienda: tienda, autor: autor, fecha: fecha_pasada)
        pedido_cocina.pedidos = [pedido]
        pedido_cocina.valid?
        expect(pedido_cocina.fecha).to be_within(1.second).of(fecha_pasada)
      end
    end
  end

  describe 'scopes' do
    describe '.by_tienda' do
      it 'responds to by_tienda scope' do
        expect(described_class).to respond_to(:by_tienda)
      end
    end
  end

  describe 'instance methods' do
    describe '#to_s' do
      it 'returns formatted string with codigo' do
        pedido_cocina = described_class.new(tienda: tienda, autor: autor, codigo: 42)
        expect(pedido_cocina.to_s).to eq 'Pedido Cocina #42'
      end
    end
  end
end
