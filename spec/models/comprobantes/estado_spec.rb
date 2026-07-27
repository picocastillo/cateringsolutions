require 'rails_helper'

RSpec.describe Comprobantes::Estado, type: :model do
  describe 'enumeration' do
    it 'has pendiente state' do
      expect(described_class[:pendiente]).to be_present
      expect(described_class[:pendiente].id).to eq(1)
      expect(described_class[:pendiente].desc).to eq('Pendiente')
    end

    it 'has confirmado state' do
      expect(described_class[:confirmado]).to be_present
      expect(described_class[:confirmado].id).to eq(2)
      expect(described_class[:confirmado].desc).to eq('Confirmado')
    end

    it 'has exactly 2 states' do
      expect(described_class.all.size).to eq(2)
    end
  end

  describe '.find' do
    it 'finds by id' do
      expect(described_class[1]).to eq(described_class[:pendiente])
      expect(described_class[2]).to eq(described_class[:confirmado])
    end
  end
end
