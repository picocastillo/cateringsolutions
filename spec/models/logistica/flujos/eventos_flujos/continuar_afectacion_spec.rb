require 'rails_helper'

RSpec.describe Logistica::Flujos::EventosFlujos::ContinuarAfectacion do
  let(:cbte) { double('Comprobante') }
  let(:estado) { double('Estado') }
  let(:evento) { described_class.new }

  before do
    allow(evento).to receive(:cbte).and_return(cbte)
    allow(cbte).to receive(:estado).and_return(estado)
  end

  describe '#en_pasado' do
    it 'returns Nueva Afectación' do
      expect(evento.en_pasado).to eq 'Nueva Afectación'
    end
  end

  describe '#disparable?' do
    it 'returns true when confirmado and importe_a_cuenta not zero' do
      allow(estado).to receive(:confirmado?).and_return(true)
      allow(cbte).to receive(:importe_a_cuenta).and_return(100.0)
      expect(evento.disparable?).to be true
    end

    it 'returns false when not confirmado' do
      allow(estado).to receive(:confirmado?).and_return(false)
      allow(cbte).to receive(:importe_a_cuenta).and_return(100.0)
      expect(evento.disparable?).to be false
    end

    it 'returns false when importe_a_cuenta is zero' do
      allow(estado).to receive(:confirmado?).and_return(true)
      allow(cbte).to receive(:importe_a_cuenta).and_return(0)
      expect(evento.disparable?).to be false
    end
  end

  describe '#validaciones_disparar' do
    it 'does not add errors when afectaciones sum is positive' do
      afectacion = double('Afectacion', importe: 50.0)
      allow(cbte).to receive(:afectaciones_no_contabilizadas).and_return([afectacion])

      evento.send(:validaciones_disparar)
      expect(evento.errors).to be_empty
    end

    it 'adds error when afectaciones sum is not positive' do
      afectacion = double('Afectacion', importe: -10.0)
      allow(cbte).to receive(:afectaciones_no_contabilizadas).and_return([afectacion])

      evento.send(:validaciones_disparar)
      expect(evento.errors[:base]).to include('No hay nuevas afectaciones a contabilizar.')
    end

    it 'adds error when no afectaciones' do
      allow(cbte).to receive(:afectaciones_no_contabilizadas).and_return([])

      evento.send(:validaciones_disparar)
      expect(evento.errors[:base]).to include('No hay nuevas afectaciones a contabilizar.')
    end
  end

  describe '#after_transition' do
    let(:usuario) { double('Usuario') }

    before do
      allow(evento).to receive(:usuario).and_return(usuario)
    end

    it 'contabilizes when cbte is valid' do
      allow(cbte).to receive(:contabilizar)
      allow(cbte).to receive_messages(valid?: true, importe_a_cuenta: 100.0)

      evento.send(:after_transition)
      expect(cbte).to have_received(:contabilizar)
    end

    it 'does not contabilize when cbte is invalid' do
      allow(cbte).to receive(:valid?).and_return(false)

      evento.send(:after_transition)
      # should not raise
    end

    it 'finalizes when importe_a_cuenta is zero' do
      allow(cbte).to receive(:contabilizar)
      allow(cbte).to receive_messages(valid?: true, importe_a_cuenta: 0)
      allow(cbte).to receive(:finalizar).with(usuario)

      evento.send(:after_transition)
      expect(cbte).to have_received(:finalizar).with(usuario)
    end

    it 'does not finalize when importe_a_cuenta is not zero' do
      allow(cbte).to receive(:contabilizar)
      allow(cbte).to receive_messages(valid?: true, importe_a_cuenta: 50.0)

      evento.send(:after_transition)
      expect(cbte).not_to have_received(:finalizar) if cbte.respond_to?(:finalizar)
    end
  end
end
