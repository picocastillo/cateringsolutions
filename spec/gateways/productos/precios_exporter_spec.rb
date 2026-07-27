require 'rails_helper'

RSpec.describe Productos::PreciosExporter do
  let(:tienda) { create(:tienda) }
  let(:autor) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let(:categoria) { create(:categoria, tienda: tienda) }
  let(:producto) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Lechuga', codigo: 'LEC01') }
  let!(:precio) { create(:precio, producto: producto, importe: 150.0, fecha_desde: Date.current, fecha_hasta: Date.current + 1.year) }

  let(:exporter) { described_class.new(autor: autor, tienda: tienda, params: { q: {} }) }

  describe '#headers' do
    it 'returns expected columns' do
      expect(exporter.headers).to include('Producto', 'Actualizado el', 'Importe', 'Fecha Desde', 'Fecha Hasta')
    end

    it 'has 10 columns' do
      expect(exporter.headers.size).to eq(10)
    end
  end

  describe '#row' do
    it 'returns precio data in correct order' do
      row = exporter.row(precio)
      expect(row[0]).to eq(precio.id)
      expect(row[3]).to eq('Lechuga')
      expect(row[9]).to eq(150.0)
    end

    it 'includes updated_at as date' do
      row = exporter.row(precio)
      expect(row[4]).to eq(precio.updated_at.to_date)
    end

    it 'includes fecha_desde as date' do
      row = exporter.row(precio)
      expect(row[7]).to eq(precio.fecha_desde.to_date)
    end
  end

  describe '#search_scope' do
    it 'returns precios for the tienda' do
      result = exporter.search_scope
      expect(result).not_to be_empty
      expect(result.map(&:id)).to include(precio.id)
    end
  end

  describe 'string-key resilience (YAML round-trip bug fix)' do
    it 'works with string keys in params' do
      params = { 'q' => {} }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      exp.run_callbacks(:save)
      result = exp.search_scope
      expect(result).not_to be_empty
    end
  end
end
