require 'rails_helper'

RSpec.describe Locales::Local, type: :model do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Local') }
  let(:local) do
    described_class.new(
      nombre: 'Local Test unit',
      tienda: tienda,
      domicilio: 'Calle Falsa 123',
      telefono: '123456789'
    )
  end

  it 'is valid with valid attributes' do
    expect(local).to be_valid
  end

  it 'requires nombre' do
    local.nombre = nil
    expect(local).not_to be_valid
    expect(local.errors[:nombre]).to be_present
  end

  it 'to_s returns nombre' do
    expect(local.to_s).to eq 'Local Test unit'
  end

  it 'tienda returns assigned tienda' do
    expect(local.tienda).to eq tienda
  end
end
