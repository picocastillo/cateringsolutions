require 'rails_helper'

RSpec.describe Logistica::Flujos::Retencion, type: :model do
  describe 'inheritance' do
    it 'inherits from MedioPago' do
      expect(described_class.superclass).to eq Logistica::Flujos::MedioPago
    end
  end

  describe 'validations' do
    it 'validates fecha_retencion as date' do
      validators = described_class.validators_on(:fecha_retencion)
      expect(validators.any? { |v| v.class.name.include?('Date') }).to be true
    end
  end

  describe 'instance methods' do
    describe '#tipo_e_importe' do
      it 'returns formatted string with tipo and importe' do
        retencion = described_class.new(importe: 50.25)
        expect(retencion.tipo_e_importe).to include('Retención:')
        expect(retencion.tipo_e_importe).to include('50')
      end
    end
  end
end
