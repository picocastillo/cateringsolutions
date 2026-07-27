require 'rails_helper'

RSpec.describe Usuarios::Rol, type: :model do
  let!(:rol) { described_class.create!(nombre: 'admin', titulo: 'Administrador', modulo: 'Usuarios') }

  it 'is valid' do
    expect(rol).to be_valid
  end

  it 'finds by symbol' do
    expect(described_class[:admin]).to eq rol
  end

  it 'raises error for undefined rol' do
    expect { described_class[:undefined] }.to raise_error(RuntimeError)
  end

  it 'compares with symbol' do
    expect(rol == :admin).to be true
    expect(rol == :other).to be false
  end

  it 'to_s returns titulo' do
    expect(rol.to_s).to eq 'Administrador'
  end
end
