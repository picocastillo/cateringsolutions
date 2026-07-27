require 'rails_helper'

RSpec.describe Ventas::Facturacion::Eventos::Pagar, type: :model do
  describe '#disparable?' do
    it 'returns true for confirmed comprobante with manual user' do
      cbte = Ventas::Facturacion::Factura.new
      allow(cbte).to receive_messages(confirmado?: true, manual?: true)
      usuario = create(:usuario)
      allow(usuario).to receive(:cumple_rol?).and_return(true)
      evento = described_class.new(origen: cbte, usuario: usuario)
      expect(evento.disparable?).to be true
    end

    it 'returns false for pendiente comprobante' do
      cbte = Ventas::Facturacion::Factura.new
      allow(cbte).to receive(:confirmado?).and_return(false)
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
    it 'returns Pagado' do
      expect(described_class.new.en_pasado).to eq('Pagado')
    end
  end
end
