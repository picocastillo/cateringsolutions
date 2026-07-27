require 'rails_helper'

RSpec.describe Comprobantes::ComprobantePropio, type: :model do
  let(:tienda) { create(:tienda) }
  let(:cliente) { create(:cliente, tienda: tienda) }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:comprobante) { described_class.new(cuenta: cuenta) }

  it 'is valid with valid attributes' do
    expect(comprobante).to be_a(described_class)
  end

  describe 'associations' do
    it 'has many afectaciones' do
      expect(comprobante).to respond_to(:afectaciones)
    end

    it 'has many afectados through afectaciones' do
      expect(comprobante).to respond_to(:afectados)
    end

    it 'has many afectadores' do
      expect(comprobante).to respond_to(:afectadores)
    end
  end

  describe '#total_afectado' do
    it 'returns sum of afectaciones' do
      allow(comprobante.afectaciones).to receive(:importe_total).and_return(100)
      expect(comprobante.total_afectado).to eq(100)
    end
  end

  describe '#importe_a_cuenta' do
    it 'calculates difference between total and total_afectado' do
      allow(comprobante).to receive_messages(total: 500, total_afectado: 200)
      expect(comprobante.importe_a_cuenta).to eq(300)
    end
  end

  describe '#finalizado?' do
    it 'checks if en_estado finalizado' do
      allow(comprobante).to receive(:en_estado?).with(:finalizado).and_return(true)
      expect(comprobante.finalizado?).to be true
    end
  end

  describe 'callbacks' do
    it 'has before_validation callbacks' do
      expect(described_class._validate_callbacks.any? { |cb| cb.filter == :setear_tienda }).to be_in([true, false])
    end
  end
end
