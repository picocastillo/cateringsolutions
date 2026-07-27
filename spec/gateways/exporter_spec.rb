require 'rails_helper'

RSpec.describe Exporter do
  let(:exporter) { described_class.new }
  let(:progreso) { double('Progreso', start: nil, finish: nil) }

  before do
    allow(exporter).to receive(:run)
    allow(exporter).to receive(:save!)
    allow(exporter).to receive_messages(progreso: progreso, search_scope: [], new_record?: false)
  end

  describe '#perform' do
    it 'calls search_scope' do
      expect(exporter).to receive(:search_scope)
      exporter.perform
    end

    it 'starts progreso' do
      expect(progreso).to receive(:start)
      exporter.perform
    end

    it 'finishes progreso' do
      expect(progreso).to receive(:finish)
      exporter.perform
    end

    it 'calls run with objects' do
      objects = [double('Object')]
      allow(exporter).to receive(:search_scope).and_return(objects)
      expect(exporter).to receive(:run).with(objects)
      exporter.perform
    end

    it 'returns self' do
      expect(exporter.perform).to eq(exporter)
    end
  end

  describe '#filepath' do
    it 'returns adjunto path' do
      adjunto = double('Adjunto', path: '/tmp/file.xls')
      allow(exporter).to receive(:adjunto).and_return(adjunto)
      expect(exporter.filepath).to eq('/tmp/file.xls')
    end
  end

  describe '#query_params' do
    it 'extracts q params and merges user' do
      exporter_with_params = described_class.new
      allow(exporter_with_params).to receive_messages(
        params: { q: { fecha: '2026-01-01' } },
        autor: double('Autor')
      )
      result = exporter_with_params.send(:query_params)
      expect(result[:fecha]).to eq('2026-01-01')
      expect(result[:user]).not_to be_nil
    end

    it 'handles nil q params gracefully' do
      exporter_with_params = described_class.new
      allow(exporter_with_params).to receive_messages(
        params: {},
        autor: double('Autor')
      )
      result = exporter_with_params.send(:query_params)
      expect(result[:user]).not_to be_nil
    end
  end
end
