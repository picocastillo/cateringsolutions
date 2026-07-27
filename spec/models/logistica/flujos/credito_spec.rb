require 'rails_helper'

RSpec.describe Logistica::Flujos::Credito, type: :model do
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
      it 'returns false' do
        credito = described_class.new
        expect(credito.efectivo?).to be false
      end
    end

    describe '#tipo_e_importe' do
      it 'returns formatted string with tipo and importe' do
        credito = described_class.new(importe: 500.00)
        expect(credito.tipo_e_importe).to include('Crédito:')
        expect(credito.tipo_e_importe).to include('500')
      end
    end
  end
end
