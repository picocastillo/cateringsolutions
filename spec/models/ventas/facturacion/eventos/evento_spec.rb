require 'rails_helper'

RSpec.describe Ventas::Facturacion::Eventos::Evento, type: :model do
  it 'inherits from Infraestructura::Eventos::Evento' do
    expect(described_class.superclass).to eq(Infraestructura::Eventos::Evento)
  end

  it 'aliases origen as cbte' do
    evento = described_class.new
    cbte = Ventas::Facturacion::Factura.new
    evento.origen = cbte
    expect(evento.cbte).to eq(cbte)
  end
end
