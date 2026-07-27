require 'rails_helper'

RSpec.describe Infraestructura::Concerns::HasOneDocumento do
  let(:test_class) do
    Class.new(ApplicationRecord) do
      self.table_name = 'tiendas' # Use an existing table for testing
      include Infraestructura::Concerns::HasOneDocumento
    end
  end

  describe 'associations' do
    it 'defines has_one :documento' do
      association = test_class.reflect_on_association(:documento)
      expect(association).to be_present
      expect(association.macro).to eq :has_one
      expect(association.options[:as]).to eq :documentable
    end
  end

  describe '#documentos' do
    it 'wraps documento in array' do
      instance = test_class.new
      allow(instance).to receive(:documento).and_return('doc')
      expect(instance.documentos).to eq ['doc']
    end

    it 'returns empty array when no documento' do
      instance = test_class.new
      allow(instance).to receive(:documento).and_return(nil)
      expect(instance.documentos).to eq []
    end
  end

  describe '#documento_ids=' do
    it 'looks up documento from first non-blank id' do
      doc = double('Documento')
      allow(Infraestructura::Documento).to receive(:find_by).with(id: '1').and_return(doc)

      instance = test_class.new
      allow(instance).to receive(:documento=)
      instance.documento_ids = ['1', '']
      expect(instance).to have_received(:documento=).with(doc)
    end

    it 'sets nil when all ids are blank' do
      instance = test_class.new
      allow(instance).to receive(:documento=)
      instance.documento_ids = ['']
      expect(instance).to have_received(:documento=).with(nil)
    end
  end
end
