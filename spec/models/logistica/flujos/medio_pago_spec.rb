require 'rails_helper'

RSpec.describe Logistica::Flujos::MedioPago, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:flujo_economico).class_name('Comprobantes::ComprobantePropio') }
    it { is_expected.to belong_to(:cuenta).class_name('Clientes::Cuenta') }
  end

  describe 'validations' do
    it 'validates importe numericality' do
      validators = described_class.validators_on(:importe)
      expect(validators.any? { |v| v.is_a?(ActiveModel::Validations::NumericalityValidator) }).to be true
    end
  end

  describe 'instance methods' do
    describe '#efectivo?' do
      it 'returns false by default' do
        medio_pago = described_class.new
        expect(medio_pago.efectivo?).to be false
      end
    end
  end
end
