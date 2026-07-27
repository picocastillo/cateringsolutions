require 'rails_helper'

RSpec.describe Logistica::Flujos::MercadoPago, type: :model do
  describe 'inheritance' do
    it 'inherits from MedioPago' do
      expect(described_class.superclass).to eq Logistica::Flujos::MedioPago
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:pago_electronico).class_name('Ventas::Facturacion::PagoElectronico') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:pago_electronico) }

    it 'validates importe numericality' do
      validators = described_class.validators_on(:importe)
      expect(validators.any? { |v| v.is_a?(ActiveModel::Validations::NumericalityValidator) }).to be true
    end
  end

  describe 'instance methods' do
    describe '#efectivo?' do
      it 'returns false' do
        mercado_pago = described_class.new
        expect(mercado_pago.efectivo?).to be false
      end
    end

    describe '#tipo_e_importe' do
      it 'returns formatted string with pago_id' do
        pago_electronico = Ventas::Facturacion::PagoElectronico.new(pago_id: 'ABC123')
        mercado_pago = described_class.new(importe: 250.75, pago_electronico: pago_electronico)
        result = mercado_pago.tipo_e_importe
        expect(result).to include('Mercado Pago:')
        expect(result).to include('250')
        expect(result).to include('ID Transacción')
      end
    end
  end
end
