require 'rails_helper'

RSpec.describe Productos::StocksExporter, type: :gateway do
  let(:tienda) { create(:tienda) }
  let(:usuario) { create(:usuario, visualizando_tienda: tienda) }
  let(:producto1) { create(:producto, nombre: 'Producto A', codigo: 'PROD001', tienda: tienda) }
  let(:producto2) { create(:producto, nombre: 'Producto B', codigo: 'PROD002', tienda: tienda) }
  let(:local) { create(:local, tienda: tienda, nombre: 'Local Central') }

  # Use stocks created by producto callback
  let!(:stock1) { producto1.stocks.first.tap { |s| s.update!(cantidad_actual: 50, cantidad_minima: 10, cantidad_maxima: 100, activo: true) } }
  let!(:stock2) { producto2.stocks.first.tap { |s| s.update!(cantidad_actual: 0, cantidad_minima: 5, cantidad_maxima: 50, activo: true) } }
  let!(:stock3) do
    # Create stock with local for producto1
    tienda.reload if tienda.multiple_locales
    if tienda.multiple_locales
      create(:stock, producto: producto1, tienda: tienda, local: local, cantidad_actual: 3, cantidad_minima: 10, cantidad_maxima: 50, activo: false)
    else
      producto1.stocks.create!(tienda: tienda, local: local, cantidad_actual: 3, cantidad_minima: 10, cantidad_maxima: 50, activo: false)
    end
  end

  let(:exporter) do
    described_class.new(
      params: { q: { solo_categorias_stock_activo: '0' } },
      autor: usuario
    )
  end

  describe '#headers' do
    it 'returns the correct headers' do
      expected_headers = [
        'ID', 'Producto', 'Código', 'Categoría', 'Cantidad Actual',
        'Cantidad Mínima', 'Cantidad Máxima', 'Estado', 'Activo',
        'Pronóstico Diario', 'Cobertura Estimada (días)', 'Mínimo Recomendado 45 días'
      ]
      expect(exporter.headers).to eq(expected_headers)
    end
  end

  describe '#row' do
    context 'with stock in normal state' do
      it 'returns correct data for stock without local' do
        row_data = exporter.row(stock1)

        expect(row_data[0]).to eq(stock1.id)
        expect(row_data[1]).to eq('Producto A')
        expect(row_data[2]).to eq('PROD001')
        expect(row_data[3]).to include(stock1.producto.categoria.nombre)
        expect(row_data[4]).to eq(50)
        expect(row_data[5]).to eq(10)
        expect(row_data[6]).to eq(100)
        expect(row_data[7]).to eq('Normal')
        expect(row_data[8]).to eq('Si')
        expect(row_data[9]).to be_a(Numeric) # Pronóstico Diario (can be Integer or Float)
        expect(row_data[10]).to be_a(Integer) # Cobertura Estimada (días)
        expect(row_data[11]).to be >= 2 # Mínimo Recomendado 45 días
      end
    end

    context 'with stock in sin stock state' do
      it 'returns correct estado "Sin Stock"' do
        row_data = exporter.row(stock2)

        expect(row_data[1]).to eq('Producto B')
        expect(row_data[4]).to eq(0)
        expect(row_data[7]).to eq('Sin Stock')
      end
    end

    context 'with stock in bajo state' do
      it 'returns correct estado "Bajo"' do
        producto_bajo = create(:producto, tienda: tienda)
        stock_bajo = producto_bajo.stocks.first.tap { |s| s.update!(cantidad_actual: 5, cantidad_minima: 10, cantidad_maxima: 50) }
        row_data = exporter.row(stock_bajo)

        expect(row_data[7]).to eq('Bajo')
      end
    end

    context 'with stock in critical state' do
      it 'returns correct estado "Crítico"' do
        producto_critico = create(:producto, tienda: tienda)
        stock_critico = producto_critico.stocks.first.tap { |s| s.update!(cantidad_actual: 1, cantidad_minima: 10, cantidad_maxima: 50) }
        row_data = exporter.row(stock_critico)

        expect(row_data[7]).to eq('Crítico')
      end
    end

    context 'with inactive stock' do
      it 'returns "No" for activo field' do
        row_data = exporter.row(stock3)

        expect(row_data[8]).to eq('No')
      end
    end
  end

  describe '#search_scope' do
    it 'returns stocks ordered by product name' do
      stocks = exporter.search_scope.to_a

      # Should be ordered by product name
      expect(stocks.map { |s| s.producto.nombre }).to eq(stocks.map { |s| s.producto.nombre }.sort)
    end

    it 'filters by user tienda_activa' do
      other_tienda = create(:tienda)
      create(:producto, tienda: other_tienda)
      # Stock is automatically created by producto callback

      stocks = exporter.search_scope.to_a

      # Should only include stocks from user's active tienda
      expect(stocks.all? { |s| s.tienda_id == tienda.id }).to be true
    end
  end

  describe 'integration with ExcelExporter' do
    it 'can export stocks to rows' do
      # Test the core export logic without full file generation
      stocks = exporter.search_scope.to_a

      expect(stocks).not_to be_empty

      # Verify each stock can be converted to a row
      stocks.each do |stock|
        row_data = exporter.row(stock)
        expect(row_data).to be_an(Array)
        expect(row_data.length).to eq(12) # Updated from 9 to 12
        expect(row_data[0]).to eq(stock.id)
        expect(row_data[1]).to eq(stock.producto.nombre)
      end
    end
  end

  describe 'categoria_con_stock private method' do
    it 'returns categoria with stock status' do
      categoria_activa = create(:categoria, tienda: tienda, nombre: 'Bebidas', stock_activo: true)
      categoria_inactiva = create(:categoria, tienda: tienda, nombre: 'Postres', stock_activo: false)

      expect(exporter.send(:categoria_con_stock, categoria_activa)).to eq('Bebidas (stock activo)')
      expect(exporter.send(:categoria_con_stock, categoria_inactiva)).to eq('Postres (stock inactivo)')
      expect(exporter.send(:categoria_con_stock, nil)).to eq('')
    end
  end

  describe 'estado_stock private method' do
    it 'returns correct status for each stock state' do
      p1 = create(:producto, tienda: tienda, nombre: "Producto Normal #{Time.current.to_f}")
      p2 = create(:producto, tienda: tienda, nombre: "Producto Bajo #{Time.current.to_f}")
      p3 = create(:producto, tienda: tienda, nombre: "Producto Crítico #{Time.current.to_f}")
      p4 = create(:producto, tienda: tienda, nombre: "Producto Sin Stock #{Time.current.to_f}")

      normal_stock = p1.stocks.first.tap { |s| s.update!(cantidad_actual: 50, cantidad_minima: 10) }
      bajo_stock = p2.stocks.first.tap { |s| s.update!(cantidad_actual: 5, cantidad_minima: 10) }
      critico_stock = p3.stocks.first.tap { |s| s.update!(cantidad_actual: 1, cantidad_minima: 10) }
      sin_stock = p4.stocks.first.tap { |s| s.update!(cantidad_actual: 0, cantidad_minima: 10) }

      expect(exporter.send(:estado_stock, normal_stock)).to eq('Normal')
      expect(exporter.send(:estado_stock, bajo_stock)).to eq('Bajo')
      expect(exporter.send(:estado_stock, critico_stock)).to eq('Crítico')
      expect(exporter.send(:estado_stock, sin_stock)).to eq('Sin Stock')
    end
  end

  describe 'string-key resilience (YAML round-trip bug fix)' do
    it 'works with string keys in params' do
      params = { 'q' => { 'solo_categorias_stock_activo' => '0' } }
      exp = described_class.new(autor: usuario, params: params)
      exp.run_callbacks(:save)
      result = exp.search_scope
      expect(result).not_to be_empty
    end

    it 'works with mixed string/symbol keys in params' do
      params = { 'q' => { solo_categorias_stock_activo: '0' } }
      exp = described_class.new(autor: usuario, params: params)
      exp.run_callbacks(:save)
      result = exp.search_scope
      expect(result).not_to be_empty
    end
  end
end
