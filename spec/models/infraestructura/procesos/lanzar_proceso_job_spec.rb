require 'rails_helper'

RSpec.describe Infraestructura::Procesos::LanzarProcesoJob, type: :job do
  describe 'inheritance' do
    it 'inherits from ApplicationJob' do
      expect(described_class.superclass).to eq ApplicationJob
    end
  end

  describe 'queue configuration' do
    it 'is queued as :slow' do
      expect(described_class.queue_name).to eq 'slow'
    end
  end

  describe '#perform' do
    let(:proceso) { double('proceso') }

    it 'calls perform on the proceso' do
      expect(proceso).to receive(:perform)
      described_class.new.perform(proceso)
    end

    it 'accepts a proceso as parameter' do
      allow(proceso).to receive(:perform)
      expect { described_class.new.perform(proceso) }.not_to raise_error
    end
  end

  describe 'callbacks' do
    describe 'after_perform' do
      it 'has an after_perform callback defined' do
        callbacks = described_class._perform_callbacks.select { |cb| cb.kind == :after }
        expect(callbacks).not_to be_empty
      end
    end
  end

  describe 'discard_on ActiveJob::DeserializationError' do
    let(:tienda) { create(:tienda) }
    let(:usuario) { create(:usuario, :admin, visualizando_tienda: tienda) }

    it 'discards the job when the proceso record was deleted before execution' do
      proceso = Productos::StocksExporter.create!(autor: usuario, tienda: tienda, params: {})
      job = described_class.new(proceso)
      serialized = job.serialize

      proceso.destroy!

      expect do
        described_class.execute(serialized)
      end.not_to raise_error
    end

    it 'is configured to discard on DeserializationError' do
      rescue_handlers = described_class.rescue_handlers
      deserialization_handler = rescue_handlers.find { |h| h[0] == 'ActiveJob::DeserializationError' }
      expect(deserialization_handler).to be_present
    end
  end
end
