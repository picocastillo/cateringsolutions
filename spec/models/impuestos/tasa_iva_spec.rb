require 'rails_helper'

RSpec.describe Impuestos::TasaIva, type: :model do
  describe 'enumeration' do
    it 'has no_gravado' do
      tasa = described_class[:no_gravado]
      expect(tasa).to be_present
      expect(tasa.alicuota).to eq(0.0)
    end

    it 'has iva_21' do
      tasa = described_class[:iva_21]
      expect(tasa).to be_present
      expect(tasa.alicuota).to eq(21.0)
    end

    it 'has iva_10_5' do
      tasa = described_class[:iva_10_5]
      expect(tasa).to be_present
      expect(tasa.alicuota).to eq(10.5)
    end
  end

  describe '#alicuota!' do
    it 'returns decimal alicuota for iva_21' do
      expect(described_class[:iva_21].alicuota!).to eq(0.21)
    end

    it 'returns decimal alicuota for iva_10_5' do
      expect(described_class[:iva_10_5].alicuota!).to eq(0.105)
    end

    it 'returns zero for no_gravado' do
      expect(described_class[:no_gravado].alicuota!).to eq(0.0)
    end
  end

  describe '#to_s' do
    it 'returns formatted string for iva_21' do
      expect(described_class[:iva_21].to_s).to eq('21%')
    end

    it 'returns formatted string for iva_10_5' do
      expect(described_class[:iva_10_5].to_s).to eq('10.5%')
    end
  end

  describe '#gravado?' do
    it 'returns true for iva_21' do
      expect(described_class[:iva_21].gravado?).to be true
    end

    it 'returns false for no_gravado' do
      expect(described_class[:no_gravado].gravado?).to be false
    end
  end
end
