# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pedidos::MedioPago, type: :model do
  let(:tienda) { create(:tienda) }
  let(:cliente) { create(:cliente, tienda: tienda) }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:autor) { create(:usuario, :admin, visualizando_tienda: tienda).tap { |u| u.tiendas << tienda } }
  let(:pedido) do
    p = Pedidos::Pedido.new(tienda: tienda, cuenta: cuenta, autor: autor, usuario: autor,
                            estado_id: 1, fecha: Date.current, venta_mostrador: true)
    p.asignar_cuenta_manual
    p.save!
    p
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      mp = described_class.new(pedido: pedido, tipo: 'efectivo', importe: 100.0)
      expect(mp).to be_valid
    end

    it 'requires tipo' do
      mp = described_class.new(pedido: pedido, tipo: nil, importe: 100.0)
      expect(mp).not_to be_valid
      expect(mp.errors[:tipo]).to be_present
    end

    it 'validates tipo inclusion' do
      mp = described_class.new(pedido: pedido, tipo: 'bitcoin', importe: 100.0)
      expect(mp).not_to be_valid
      expect(mp.errors[:tipo]).to be_present
    end

    it 'requires importe > 0' do
      mp = described_class.new(pedido: pedido, tipo: 'efectivo', importe: 0)
      expect(mp).not_to be_valid
      expect(mp.errors[:importe]).to be_present
    end

    it 'rejects negative importe' do
      mp = described_class.new(pedido: pedido, tipo: 'efectivo', importe: -10)
      expect(mp).not_to be_valid
    end

    ['efectivo', 'debito', 'credito', 'qr', 'transferencia'].each do |tipo|
      it "accepts tipo '#{tipo}'" do
        mp = described_class.new(pedido: pedido, tipo: tipo, importe: 50.0)
        expect(mp).to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to pedido' do
      mp = described_class.new(pedido: pedido, tipo: 'efectivo', importe: 100.0)
      expect(mp.pedido).to eq(pedido)
    end
  end

  describe '#tipo_label' do
    it 'returns human-readable label' do
      mp = described_class.new(tipo: 'qr')
      expect(mp.tipo_label).to eq('QR')
    end

    it 'returns Débito for debito' do
      mp = described_class.new(tipo: 'debito')
      expect(mp.tipo_label).to eq('Débito')
    end
  end

  describe 'TIPOS' do
    it 'has 5 payment types' do
      expect(described_class::TIPOS.size).to eq(5)
    end
  end
end
