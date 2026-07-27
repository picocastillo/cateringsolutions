require 'rails_helper'

RSpec.describe Logistica::Flujos::FlujoEconomico, type: :model do
  describe 'MediosPago constant' do
    it 'includes all 7 medio types' do
      expected = [:efectivos, :retenciones, :mercado_pagos, :debitos, :creditos, :qrs, :transferencias]
      expect(described_class::MediosPago).to match_array(expected)
    end

    it 'is frozen' do
      expect(described_class::MediosPago).to be_frozen
    end
  end

  describe 'associations' do
    [:efectivos, :retenciones, :mercado_pagos, :debitos, :creditos, :qrs, :transferencias].each do |medio|
      it "has_many #{medio}" do
        assoc = described_class.reflect_on_association(medio)
        expect(assoc).not_to be_nil
        expect(assoc.macro).to eq :has_many
      end
    end

    [:efectivos, :retenciones, :debitos, :creditos, :qrs, :transferencias].each do |medio|
      it "accepts nested attributes for #{medio}" do
        expect(described_class.nested_attributes_options.keys.map(&:to_sym)).to include(medio)
      end
    end
  end
end
