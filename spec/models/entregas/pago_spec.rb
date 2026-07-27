require 'rails_helper'

RSpec.describe Entregas::Pago, type: :model do
  describe 'inheritance' do
    it 'inherits from FlujoEconomico' do
      expect(described_class.superclass).to eq Logistica::Flujos::FlujoEconomico
    end
  end

  describe 'instance methods' do
    let(:pago) { described_class.new(nro: 456) }

    describe '#to_s' do
      it 'returns formatted string with Pago prefix' do
        expect(pago.to_s).to eq 'Pago 456'
      end
    end

    describe '#debita?' do
      it 'returns true' do
        expect(pago.debita?).to be true
      end
    end

    describe '#importe_a_cuenta' do
      it 'calculates total plus total_afectado' do
        pago.total = 100
        allow(pago).to receive(:total_afectado).and_return(50)
        expect(pago.importe_a_cuenta).to eq 150
      end

      it 'handles zero values' do
        pago.total = 0
        allow(pago).to receive(:total_afectado).and_return(0)
        expect(pago.importe_a_cuenta).to eq 0
      end
    end

    describe '#secuenciador' do
      it 'returns tienda-specific sequencer name' do
        pago.tienda_id = 3
        expect(pago.secuenciador).to eq 'tienda3_pagos'
      end
    end
  end

  describe 'callbacks' do
    describe '#asignar_tipo' do
      it 'assigns tipo with codigo 6 for new records' do
        tipo = Comprobantes::Tipo.find_or_create_by!(codigo: 6) do |t|
          t.desc = 'Orden de Pago'
          t.clase = 'Entregas::Pago'
          t.letra = 'X'
        end

        pago = described_class.new
        pago.send(:asignar_tipo)
        expect(pago.tipo).to eq tipo
      end

      it 'does not assign tipo for existing records' do
        pago = described_class.new
        allow(pago).to receive(:new_record?).and_return(false)
        pago.send(:asignar_tipo)
        expect(pago.tipo).to be_nil
      end
    end
  end

  describe 'validations' do
    describe '#afectados_debitan' do
      it 'adds error when afectado debits' do
        tienda = create(:tienda)
        cliente = create(:cliente, tienda: tienda)
        cuenta = create(:cuenta, cliente: cliente)
        pago = described_class.new(cuenta: cuenta)

        afectacion = double('afectacion', afectado: double('comprobante', debita?: true, to_s: 'Test', cuenta: cuenta))
        allow(pago).to receive_message_chain(:afectaciones, :select).and_return([afectacion])

        pago.send(:afectados_debitan)
        expect(pago.errors[:base]).to be_present
      end
    end
  end
end
