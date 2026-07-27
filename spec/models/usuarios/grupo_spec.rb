require 'rails_helper'

RSpec.describe Usuarios::Grupo, type: :model do
  let(:grupo) { described_class.new(nombre: 'Operadores') }

  it 'is valid' do
    expect(grupo).to be_valid
  end

  it 'requires nombre' do
    grupo.nombre = nil
    expect(grupo).not_to be_valid
    expect(grupo.errors[:nombre]).to be_present
  end

  it 'does not allow duplicate nombre' do
    grupo.save!
    grupo2 = described_class.new(nombre: 'Operadores')
    expect(grupo2).not_to be_valid
    expect(grupo2.errors[:nombre]).to be_present
  end

  it 'to_s returns nombre' do
    expect(grupo.to_s).to eq 'Operadores'
  end

  it 'especial? returns true for operadores' do
    expect(grupo.especial?).to be true
  end
end
