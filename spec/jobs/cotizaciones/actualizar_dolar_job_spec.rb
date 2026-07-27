require 'rails_helper'

RSpec.describe Cotizaciones::ActualizarDolarJob, type: :job do
  describe '#perform' do
    it 'calls Cotizaciones::Dolar.actualizar! with the given date' do
      expect(Cotizaciones::Dolar).to receive(:actualizar!).with(Date.new(2026, 3, 8))
      described_class.new.perform('2026-03-08')
    end

    it 'defaults to Date.current when no date given' do
      expect(Cotizaciones::Dolar).to receive(:actualizar!).with(Date.current)
      described_class.new.perform
    end

    it 'skips when rate already exists for the date' do
      Cotizaciones::Dolar.create!(fecha: Date.current, precio_venta: 1425.0)
      expect(Cotizaciones::Dolar).not_to receive(:actualizar!)
      described_class.new.perform(Date.current.to_s)
    end

    it 'is enqueued in the fast queue' do
      expect(described_class.new.queue_name).to eq('fast')
    end
  end
end
