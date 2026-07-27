require 'rails_helper'

RSpec.describe Ventas::Facturacion::OrdenPago, type: :model do
  it 'is valid with valid attributes' do
    expect(described_class.new).to be_a(described_class)
  end

  describe '#orden_pago?' do
    it 'returns true' do
      expect(described_class.new.orden_pago?).to be true
    end
  end

  describe '#debita?' do
    it 'returns false' do
      expect(described_class.new.debita?).to be false
    end
  end

  describe '#determinar_letra' do
    it 'returns OP' do
      expect(described_class.new.determinar_letra).to eq 'OP'
    end
  end

  describe '#asignar_tipo' do
    before do
      Comprobantes::Tipo.find_or_create_by(codigo: 5) do |t|
        t.desc = 'Orden de Pago O'
        t.letra = 'C'
        t.clase = 'Facturacion::OrdenPago'
        t.debitan = false
      end
    end

    it 'assigns tipo with codigo 5 on new records' do
      orden = described_class.new
      orden.send(:asignar_tipo)
      expect(orden.tipo).to eq Comprobantes::Tipo.find_by(codigo: 5)
    end

    it 'does not assign tipo on persisted records' do
      orden = described_class.new
      allow(orden).to receive(:new_record?).and_return(false)
      orden.send(:asignar_tipo)
      expect(orden.tipo).to be_nil
    end
  end
end
