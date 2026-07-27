require 'rails_helper'

RSpec.describe Referencia::Genero, type: :model do
  describe 'enumeration' do
    it 'has hombre' do
      expect(described_class[:hombre]).to be_present
      expect(described_class[:hombre].desc).to eq 'Hombre'
    end

    it 'has mujer' do
      expect(described_class[:mujer]).to be_present
      expect(described_class[:mujer].desc).to eq 'Mujer'
    end

    it 'has exactly 2 values' do
      expect(described_class.all.size).to eq 2
    end

    it 'can access by name symbol' do
      expect(described_class[:hombre].name).to eq 'hombre'
      expect(described_class[:mujer].name).to eq 'mujer'
    end
  end

  describe '#to_s' do
    it 'returns desc for hombre' do
      expect(described_class[:hombre].to_s).to eq 'Hombre'
    end

    it 'returns desc for mujer' do
      expect(described_class[:mujer].to_s).to eq 'Mujer'
    end
  end
end
