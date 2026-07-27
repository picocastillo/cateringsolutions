require 'rails_helper'

RSpec.describe Comprobantes::Afectacion, type: :model do
  describe 'associations' do
    it 'belongs to comprobante' do
      expect(described_class.reflect_on_association(:comprobante).macro).to eq(:belongs_to)
    end

    it 'belongs to afectado' do
      expect(described_class.reflect_on_association(:afectado).macro).to eq(:belongs_to)
    end
  end

  describe 'money columns' do
    it 'has importe as money column' do
      afectacion = described_class.new(importe: 100.50)
      expect(afectacion.importe).to be_a(Danconia::Money)
    end
  end

  describe 'validations' do
    describe '#validar_importe' do
      context 'when afectado debits' do
        it 'adds error when importe is negative' do
          afectado = double('afectado', debita?: true, marked_for_destruction?: false)
          afectacion = described_class.new
          allow(afectacion).to receive(:afectado).and_return(afectado)
          afectacion.importe = -100
          afectacion.valid?
          expect(afectacion.errors[:importe]).to include('debe ser mayor o igual a 0')
        end

        it 'is valid when importe is positive' do
          afectado = double('afectado', debita?: true, marked_for_destruction?: false)
          afectacion = described_class.new
          allow(afectacion).to receive(:afectado).and_return(afectado)
          afectacion.importe = 100
          afectacion.valid?
          expect(afectacion.errors[:importe]).to be_empty
        end
      end

      context 'when afectado does not debit' do
        it 'adds error when importe is positive' do
          afectado = double('afectado', debita?: false, marked_for_destruction?: false)
          afectacion = described_class.new
          allow(afectacion).to receive(:afectado).and_return(afectado)
          afectacion.importe = 100
          afectacion.valid?
          expect(afectacion.errors[:importe]).to include('debe ser menor o igual a 0')
        end

        it 'is valid when importe is negative' do
          afectado = double('afectado', debita?: false, marked_for_destruction?: false)
          afectacion = described_class.new
          allow(afectacion).to receive(:afectado).and_return(afectado)
          afectacion.importe = -100
          afectacion.valid?
          expect(afectacion.errors[:importe]).to be_empty
        end
      end
    end
  end

  describe 'instance methods' do
    describe '#generar_movimientos' do
      it 'responds to generar_movimientos' do
        afectacion = described_class.new
        expect(afectacion).to respond_to(:generar_movimientos)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_destroy' do
      it 'has borrar_movimientos callback' do
        callbacks = described_class._destroy_callbacks.select { |cb| cb.kind == :before }
        callback_names = callbacks.map(&:filter)
        expect(callback_names).to include(:borrar_movimientos)
      end
    end
  end
end
