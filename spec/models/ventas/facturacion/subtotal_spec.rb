require 'rails_helper'

RSpec.describe Ventas::Facturacion::Subtotal, type: :model do
  let(:tienda) { create(:tienda) }
  let(:cliente) { create(:cliente, tienda: tienda) }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:tipo_factura) do
    Comprobantes::Tipo.find_or_create_by!(codigo: 1) do |t|
      t.desc = 'Factura'
      t.clase = 'Ventas::Facturacion::Factura'
      t.letra = 'A'
    end
  end
  let(:comprobante) { Ventas::Facturacion::Factura.new(cuenta: cuenta, tienda: tienda, tipo: tipo_factura) }

  describe 'associations' do
    it 'belongs to comprobante' do
      expect(described_class.reflect_on_association(:comprobante).macro).to eq(:belongs_to)
    end
  end

  describe 'money columns' do
    it 'has base_imponible as money' do
      subtotal = described_class.new(base_imponible: 100.50)
      expect(subtotal.base_imponible).to be_a(Danconia::Money)
    end

    it 'has iva as money' do
      subtotal = described_class.new(iva: 21.0)
      expect(subtotal.iva).to be_a(Danconia::Money)
    end
  end

  describe '#total_con_iva' do
    it 'sums base_imponible and iva' do
      subtotal = described_class.new(base_imponible: 1000, iva: 210)
      expect(subtotal.total_con_iva.to_f).to eq(1210)
    end

    it 'returns base_imponible when iva is zero' do
      subtotal = described_class.new(base_imponible: 500, iva: 0)
      expect(subtotal.total_con_iva.to_f).to eq(500)
    end
  end

  describe 'tasa_iva delegation' do
    it 'delegates gravado? to tasa_iva' do
      subtotal = described_class.new(tasa_iva: :iva_21)
      expect(subtotal.gravado?).to be true
    end

    it 'delegates no_gravado? to tasa_iva' do
      subtotal = described_class.new(tasa_iva: :no_gravado)
      expect(subtotal.no_gravado?).to be true
    end
  end

  describe 'validations' do
    it 'requires positive base_imponible' do
      subtotal = described_class.new(base_imponible: -100, iva: 0, comprobante: comprobante, tasa_iva: :no_gravado)
      expect(subtotal).not_to be_valid
      expect(subtotal.errors[:base_imponible]).to be_present
    end
  end

  describe '#to_wsfe' do
    it 'returns hash with id, base_imp and importe' do
      subtotal = described_class.new(base_imponible: 1000, iva: 210, tasa_iva: :iva_21)
      wsfe = subtotal.to_wsfe
      expect(wsfe[:id]).to eq(Impuestos::TasaIva[:iva_21].codigo)
      expect(wsfe[:base_imp]).to eq(1000.0)
      expect(wsfe[:importe]).to eq(210.0)
    end
  end
end
