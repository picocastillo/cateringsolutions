require 'rails_helper'

RSpec.describe Logistica::Flujos::Debito, type: :model do
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
        debito = described_class.new
        expect(debito.efectivo?).to be false
      end
    end

    describe '#tipo_e_importe' do
      it 'returns formatted string with tipo and importe' do
        debito = described_class.new(importe: 250.00)
        expect(debito.tipo_e_importe).to include('Débito:')
        expect(debito.tipo_e_importe).to include('250')
      end
    end
  end
end
