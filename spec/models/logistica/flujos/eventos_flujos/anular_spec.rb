require 'rails_helper'

RSpec.describe Logistica::Flujos::EventosFlujos::Anular do
  let(:cbte) { double('Comprobante') }
  let(:estado) { double('Estado') }
  let(:evento) { described_class.new }

  before do
    allow(evento).to receive(:cbte).and_return(cbte)
    allow(cbte).to receive(:estado).and_return(estado)
  end

  describe '#en_pasado' do
    it 'returns Anulado' do
      expect(evento.en_pasado).to eq 'Anulado'
    end
  end

  describe '#disparable?' do
    it 'returns true when cbte is not anulado' do
      allow(estado).to receive(:anulado?).and_return(false)
      expect(evento.disparable?).to be true
    end

    it 'returns false when cbte is already anulado' do
      allow(estado).to receive(:anulado?).and_return(true)
      expect(evento.disparable?).to be false
    end
  end

  describe '#estado_siguiente' do
    it 'returns :anulado' do
      expect(evento.send(:estado_siguiente)).to eq :anulado
    end
  end

  describe '#after_transition' do
    it 'updates saldo on afectado movimientos and destroys cbte movimientos' do
      movimiento1 = double('Movimiento', saldo: 100.0)
      allow(movimiento1).to receive(:saldo=)
      allow(movimiento1).to receive(:save!)

      afectado = double('Afectado', movimientos: [movimiento1])
      afectacion = double('Afectacion', afectado: afectado, importe: 50.0)
      afectaciones = [afectacion]
      cbte_movimientos = double('Movimientos')

      allow(cbte).to receive_messages(afectaciones: afectaciones, movimientos: cbte_movimientos)
      allow(cbte_movimientos).to receive(:destroy_all)

      evento.send(:after_transition)

      expect(movimiento1).to have_received(:saldo=).with(150.0)
      expect(movimiento1).to have_received(:save!)
      expect(cbte_movimientos).to have_received(:destroy_all)
    end

    it 'handles multiple afectaciones' do
      mov1 = double('Mov1', saldo: 0.0)
      allow(mov1).to receive(:saldo=)
      allow(mov1).to receive(:save!)

      mov2 = double('Mov2', saldo: 200.0)
      allow(mov2).to receive(:saldo=)
      allow(mov2).to receive(:save!)

      afectado1 = double('Afectado1', movimientos: [mov1])
      afectado2 = double('Afectado2', movimientos: [mov2])
      af1 = double('Af1', afectado: afectado1, importe: 100.0)
      af2 = double('Af2', afectado: afectado2, importe: 50.0)

      cbte_movimientos = double('CbteMovimientos')
      allow(cbte).to receive_messages(afectaciones: [af1, af2], movimientos: cbte_movimientos)
      allow(cbte_movimientos).to receive(:destroy_all)

      evento.send(:after_transition)

      expect(mov1).to have_received(:saldo=).with(100.0)
      expect(mov2).to have_received(:saldo=).with(250.0)
    end
  end
end
