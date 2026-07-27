require 'rails_helper'

RSpec.describe Contabilidad::Movimiento, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:comprobante).class_name('Comprobantes::Comprobante') }
    it { is_expected.to belong_to(:imputado).class_name('Comprobantes::Comprobante').optional }
    it { is_expected.to belong_to(:afectacion).class_name('Comprobantes::Afectacion').optional }
    it { is_expected.to belong_to(:cuenta).class_name('Clientes::Cuenta') }
    it { is_expected.to belong_to(:tienda).class_name('Tiendas::Tienda') }
  end

  describe 'instance methods' do
    let(:movimiento) { described_class.new }

    describe '#debe' do
      it 'returns importe when positive' do
        movimiento.importe = 100
        movimiento.saldo = 100
        movimiento.condicion = nil
        allow(movimiento).to receive_message_chain(:comprobante, :estado).and_return(:confirmado)
        expect(movimiento.debe).to eq 100
      end

      it 'returns nil when negative' do
        movimiento.importe = -100
        movimiento.saldo = -100
        movimiento.condicion = nil
        allow(movimiento).to receive_message_chain(:comprobante, :estado).and_return(:confirmado)
        expect(movimiento.debe).to be_nil
      end
    end

    describe '#haber' do
      it 'returns nil when positive' do
        movimiento.importe = 100
        movimiento.saldo = 100
        movimiento.condicion = nil
        allow(movimiento).to receive_message_chain(:comprobante, :estado).and_return(:confirmado)
        expect(movimiento.haber).to be_nil
      end

      it 'returns positive value when negative' do
        movimiento.importe = -100
        movimiento.saldo = -100
        movimiento.condicion = nil
        allow(movimiento).to receive_message_chain(:comprobante, :estado).and_return(:confirmado)
        expect(movimiento.haber).to eq 100
      end
    end

    describe '#estado' do
      it 'returns Confirmado when saldo is zero' do
        movimiento.saldo = 0
        expect(movimiento.estado).to eq 'Confirmado'
      end

      it 'returns Parcial when saldo differs from importe' do
        movimiento.importe = 100
        movimiento.saldo = 50
        expect(movimiento.estado).to eq 'Parcial'
      end

      it 'returns Pendiente when saldo equals importe' do
        movimiento.importe = 100
        movimiento.saldo = 100
        expect(movimiento.estado).to eq 'Pendiente'
      end
    end
  end

  # Bug A: setear_tienda relied on the legacy `cliente.tienda` shim which
  # silently returned `cliente.tiendas.first` for clientes shared across
  # multiple tiendas. Movimientos must inherit from the comprobante (the
  # authoritative source) rather than guess.
  describe '#setear_tienda (Bug A)' do
    let(:tienda_a) { Tiendas::Tienda.create!(nombre: 'Movim Tienda A') }
    let(:tienda_b) { Tiendas::Tienda.create!(nombre: 'Movim Tienda B') }
    let(:cliente) do
      Clientes::Cliente.create!(
        nombre: 'Cliente shared',
        cuit: '20294834487',
        dia_inicio_ciclo_facturacion: 1,
        vencimiento_a: 1,
        horario_corte_pedidos: '12:00',
        tiendas: [tienda_a, tienda_b]
      )
    end
    let(:cuenta) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Shared cta') }

    it 'derives tienda from the comprobante when available' do
      comprobante = double('Comprobante', tienda: tienda_b, tienda_id: tienda_b.id).as_null_object
      mov = described_class.new(cuenta: cuenta, importe: 100, saldo: 100)
      allow(mov).to receive(:comprobante).and_return(comprobante)

      mov.send(:setear_tienda)

      expect(mov.tienda).to eq(tienda_b)
    end
  end
end
