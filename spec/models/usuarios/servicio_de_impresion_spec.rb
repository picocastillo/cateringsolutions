require 'rails_helper'

RSpec.describe Usuarios::ServicioDeImpresion do
  it 'has whb as id 1' do
    expect(described_class[:whb].id).to eq(1)
  end

  it 'has qztray as id 2' do
    expect(described_class[:qztray].id).to eq(2)
  end

  it 'has two values' do
    expect(described_class.all.size).to eq(2)
  end

  it 'has descriptive labels' do
    expect(described_class[:whb].desc).to eq('WHB')
    expect(described_class[:qztray].desc).to eq('QZ Tray')
  end
end
