require 'rails_helper'

RSpec.describe Ventas::Facturacion::Eventos::Cobrar, type: :model do
  describe '#disparable?' do
    it 'returns true for confirmed comprobante without user (automatic)' do
      cbte = Ventas::Facturacion::Factura.new
      allow(cbte).to receive_messages(confirmado?: true, manual?: false)
      evento = described_class.new(origen: cbte, usuario: nil)
      expect(evento.disparable?).to be true
    end

    it 'returns false for pendiente comprobante' do
      cbte = Ventas::Facturacion::Factura.new
      allow(cbte).to receive_messages(confirmado?: false, manual?: false)
      evento = described_class.new(origen: cbte)
      expect(evento.disparable?).to be false
    end
  end

  describe '#estado_siguiente' do
    it 'returns :confirmado' do
      expect(described_class.new.estado_siguiente).to eq(:confirmado)
    end
  end

  describe '#en_pasado' do
    it 'returns Cobrado' do
      expect(described_class.new.en_pasado).to eq('Cobrado')
    end
  end

  describe '#disparable_automatico?' do
    it 'returns true when no user present' do
      evento = described_class.new(usuario: nil)
      expect(evento.disparable_automatico?).to be true
    end

    it 'returns false when user present' do
      usuario = create(:usuario)
      evento = described_class.new(usuario: usuario)
      expect(evento.disparable_automatico?).to be false
    end
  end
end
