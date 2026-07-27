require 'rails_helper'

RSpec.describe Logistica::Flujos::Transferencia, type: :model do
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
        transferencia = described_class.new
        expect(transferencia.efectivo?).to be false
      end
    end

    describe '#tipo_e_importe' do
      it 'returns formatted string with tipo and importe' do
        transferencia = described_class.new(importe: 1200.00)
        expect(transferencia.tipo_e_importe).to include('Transferencia:')
        expect(transferencia.tipo_e_importe).to include('1.200')
      end
    end
  end
end
