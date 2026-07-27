require 'rails_helper'

RSpec.describe Ventas::Facturacion::Eventos::Confirmar, type: :model do
  let(:tienda) { create(:tienda) }
  let(:cliente) { create(:cliente, tienda: tienda) }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:usuario) do
    user = create(:usuario, :admin, visualizando_tienda: tienda)
    user.tiendas << tienda unless user.tiendas.include?(tienda)
    user
  end

  let!(:tipo_factura) do
    Comprobantes::Tipo.find_or_create_by!(codigo: 1) do |t|
      t.desc = 'Factura'
      t.clase = 'Ventas::Facturacion::Factura'
      t.letra = 'A'
    end
  end

  describe '#disparable?' do
    it 'returns true for pendiente automatico comprobante' do
      cbte = Ventas::Facturacion::Factura.new(cuenta: cuenta, tienda: tienda, automatico: true)
      evento = described_class.new(origen: cbte)
      allow(cbte).to receive(:pendiente?).and_return(true)
      expect(evento.disparable?).to be true
    end

    it 'returns false for non-pendiente comprobante' do
      cbte = Ventas::Facturacion::Factura.new(cuenta: cuenta, tienda: tienda)
      evento = described_class.new(origen: cbte)
      allow(cbte).to receive(:pendiente?).and_return(false)
      expect(evento.disparable?).to be false
    end
  end

  describe '#estado_siguiente' do
    it 'returns :confirmado' do
      expect(described_class.new.estado_siguiente).to eq(:confirmado)
    end
  end

  describe '#en_pasado' do
    it 'returns Confirmado' do
      expect(described_class.new.en_pasado).to eq('Confirmado')
    end
  end

  describe '#disparable_automatico?' do
    it 'returns true for factura' do
      cbte = Ventas::Facturacion::Factura.new
      evento = described_class.new(origen: cbte)
      expect(evento.disparable_automatico?).to be true
    end

    it 'returns falsy for NC without cancela_a' do
      cbte = Ventas::Facturacion::NotaCredito.new
      allow(cbte).to receive(:cancela_a).and_return(nil)
      evento = described_class.new(origen: cbte)
      expect(evento).not_to be_disparable_automatico
    end

    it 'returns truthy for NC with cancela_a' do
      factura = Ventas::Facturacion::Factura.new
      cbte = Ventas::Facturacion::NotaCredito.new
      allow(cbte).to receive(:cancela_a).and_return(factura)
      evento = described_class.new(origen: cbte)
      expect(evento).to be_disparable_automatico
    end
  end
end
