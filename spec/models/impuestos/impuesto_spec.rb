require 'rails_helper'

RSpec.describe Impuestos::Impuesto, type: :model do
  describe 'enumeration' do
    it 'has iva' do
      expect(described_class[:iva]).to be_present
      expect(described_class[:iva].desc).to eq('IVA')
    end

    it 'has iibb' do
      expect(described_class[:iibb]).to be_present
      expect(described_class[:iibb].desc).to eq('Ingresos Brutos')
      expect(described_class[:iibb].abrev).to eq('IIBB')
    end

    it 'has gcias' do
      expect(described_class[:gcias]).to be_present
      expect(described_class[:gcias].desc).to eq('Ganancias')
    end

    it 'has suss' do
      expect(described_class[:suss]).to be_present
      expect(described_class[:suss].desc).to eq('SUSS')
    end
  end

  describe '#to_s' do
    it 'returns abrev when present' do
      expect(described_class[:iibb].to_s).to eq('IIBB')
    end

    it 'returns desc when no abrev' do
      expect(described_class[:iva].to_s).to eq('IVA')
    end
  end
end
