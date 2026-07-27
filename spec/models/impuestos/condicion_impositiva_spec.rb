require 'rails_helper'

RSpec.describe Impuestos::CondicionImpositiva, type: :model do
  describe 'enumeration' do
    it 'has inscripto_gcias' do
      cond = described_class[:inscripto_gcias]
      expect(cond).to be_present
      expect(cond.aplicable_a).to eq(:gcias)
    end

    it 'has inscripto_iva' do
      cond = described_class[:inscripto_iva]
      expect(cond).to be_present
      expect(cond.aplicable_a).to eq(:iva)
    end

    it 'has monotributista' do
      cond = described_class[:monotributista]
      expect(cond).to be_present
      expect(cond.aplicable_a).to eq(:iva)
    end

    it 'has consumidor_final' do
      cond = described_class[:consumidor_final]
      expect(cond).to be_present
    end
  end

  describe '.all_for' do
    it 'returns only gcias conditions' do
      result = described_class.all_for(:gcias)
      expect(result.all? { |ci| ci.aplicable_a == :gcias }).to be true
    end

    it 'returns only iva conditions' do
      result = described_class.all_for(:iva)
      expect(result.all? { |ci| ci.aplicable_a == :iva }).to be true
    end

    it 'returns only iibb conditions' do
      result = described_class.all_for(:iibb)
      expect(result.all? { |ci| ci.aplicable_a == :iibb }).to be true
    end
  end

  describe '.find_by_id' do
    it 'finds inscripto_iva by id' do
      result = described_class.find_by_id(5) # rubocop:disable Rails/DynamicFindBy
      expect(result).to eq(described_class[:inscripto_iva])
    end

    it 'finds monotributista by id' do
      result = described_class.find_by_id(7) # rubocop:disable Rails/DynamicFindBy
      expect(result).to eq(described_class[:monotributista])
    end

    it 'returns nil for invalid id' do
      result = described_class.find_by_id(9999) # rubocop:disable Rails/DynamicFindBy
      expect(result).to be_nil
    end
  end
end
