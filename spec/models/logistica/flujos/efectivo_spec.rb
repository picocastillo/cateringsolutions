require 'rails_helper'

RSpec.describe Logistica::Flujos::Efectivo, type: :model do
  describe 'inheritance' do
    it 'inherits from MedioPago' do
      expect(described_class.superclass).to eq Logistica::Flujos::MedioPago
    end
  end

  describe 'validations' do
    it 'validates importe numericality' do
      validators = described_class.validators_on(:importe)
      expect(validators.any? { |v| v.is_a?(ActiveModel::Validations::NumericalityValidator) }).to be true
    end
  end

  describe 'instance methods' do
    describe '#efectivo?' do
      it 'returns true' do
        efectivo = described_class.new
        expect(efectivo.efectivo?).to be true
      end
    end

    describe '#tipo_e_importe' do
      it 'returns formatted string with tipo and importe' do
        efectivo = described_class.new(importe: 100.50)
        expect(efectivo.tipo_e_importe).to include('Efectivo:')
        expect(efectivo.tipo_e_importe).to include('100')
      end
    end
  end
end
