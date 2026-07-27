require 'rails_helper'

RSpec.describe Productos::StocksQuery, type: :query do
  let(:tienda) { create(:tienda) }
  let(:usuario) { create(:usuario, visualizando_tienda: tienda) }

  let(:categoria_activa) { create(:categoria, tienda: tienda, stock_activo: true, nombre: 'Con Stock') }
  let(:categoria_inactiva) { create(:categoria, tienda: tienda, stock_activo: false, nombre: 'Sin Stock') }

  let!(:producto_activo) { create(:producto, tienda: tienda, categoria: categoria_activa, nombre: 'Producto A') }
  let!(:producto_inactivo) { create(:producto, tienda: tienda, categoria: categoria_inactiva, nombre: 'Producto B') }

  let!(:stock_activo) do
    producto_activo.reload.stocks.first.tap { |s| s.update!(cantidad_actual: 50, cantidad_minima: 10, activo: true) }
  end

  let!(:stock_inactivo) do
    # Manually create stock for producto_inactivo since its categoria has stock_activo: false
    Productos::Stock.create!(
      producto: producto_inactivo,
      tienda: tienda,
      local_id: nil,
      cantidad_actual: 30,
      cantidad_minima: 5,
      activo: true
    )
  end

  describe 'solo_categorias_stock_activo filter' do
    context 'when enabled (default)' do
      it 'only returns stocks from categories with stock_activo = true' do
        query = described_class.new(user: usuario)
        results = query.to_a

        expect(results).to include(stock_activo)
        expect(results).not_to include(stock_inactivo)
      end

      it 'joins with categorias table' do
        query = described_class.new(user: usuario)
        expect(query.to_sql).to include('categorias')
      end
    end

    context 'when explicitly disabled' do
      it 'returns all stocks' do
        query = described_class.new(user: usuario, solo_categorias_stock_activo: '0')
        results = query.to_a

        expect(results).to include(stock_activo)
        expect(results).to include(stock_inactivo)
      end
    end

    context 'when set to false' do
      it 'returns all stocks' do
        query = described_class.new(user: usuario, solo_categorias_stock_activo: false)
        results = query.to_a

        expect(results).to include(stock_activo)
        expect(results).to include(stock_inactivo)
      end
    end
  end

  describe 'status_stock filter' do
    let!(:stock_normal) do
      p = create(:producto, tienda: tienda, categoria: categoria_activa)
      p.stocks.first.tap { |s| s.update!(cantidad_actual: 50, cantidad_minima: 10) }
    end

    let!(:stock_bajo) do
      p = create(:producto, tienda: tienda, categoria: categoria_activa)
      p.stocks.first.tap { |s| s.update!(cantidad_actual: 5, cantidad_minima: 10) }
    end

    let!(:stock_critico) do
      p = create(:producto, tienda: tienda, categoria: categoria_activa)
      p.stocks.first.tap { |s| s.update!(cantidad_actual: 1, cantidad_minima: 10) }
    end

    let!(:stock_sin) do
      p = create(:producto, tienda: tienda, categoria: categoria_activa)
      p.stocks.first.tap { |s| s.update!(cantidad_actual: 0, cantidad_minima: 10) }
    end

    context 'when filtering by con_stock' do
      it 'returns all items with stock > 0' do
        query = described_class.new(user: usuario, status_stock_ids: 'con_stock')
        results = query.to_a

        # con_stock includes normal, bajo, and critico (if > 0)
        expect(results).to include(stock_normal, stock_bajo, stock_critico)
        expect(results).not_to include(stock_sin)
      end
    end

    context 'when filtering by stock_bajo' do
      it 'returns only low stock items' do
        query = described_class.new(user: usuario, status_stock_ids: 'stock_bajo')
        results = query.to_a

        # stock_bajo: cantidad <= minima AND cantidad > 0
        # stock_bajo (5 <= 10 AND 5 > 0) ✓
        # stock_critico (1 <= 10 but matches critico scope too)
        expect(results).to include(stock_bajo)
        expect(results).not_to include(stock_normal, stock_sin)
        # NOTE: stock_critico may or may not be included depending on query logic
      end
    end

    context 'when filtering by stock_critico' do
      it 'returns only critical stock items' do
        query = described_class.new(user: usuario, status_stock_ids: 'stock_critico')
        results = query.to_a

        # stock_critico: cantidad = 0 OR (cantidad < minima AND cantidad <= 1)
        expect(results).to include(stock_critico, stock_sin)
        expect(results).not_to include(stock_normal, stock_bajo)
      end
    end

    context 'when filtering by sin_stock' do
      it 'returns only out of stock items' do
        query = described_class.new(user: usuario, status_stock_ids: 'sin_stock')
        results = query.to_a

        expect(results).to include(stock_sin)
        expect(results).not_to include(stock_normal, stock_bajo, stock_critico)
      end
    end

    context 'when filtering by multiple statuses (OR logic)' do
      it 'returns items matching any of the selected statuses' do
        query = described_class.new(user: usuario, status_stock_ids: ['stock_bajo', 'stock_critico'])
        results = query.to_a

        # Should include both bajo (5 units) and critico (1 unit, 0 units)
        expect(results).to include(stock_bajo, stock_critico, stock_sin)
        expect(results).not_to include(stock_normal)
      end

      it 'returns items with stock_bajo OR sin_stock' do
        query = described_class.new(user: usuario, status_stock_ids: ['stock_bajo', 'sin_stock'])
        results = query.to_a

        # stock_bajo: cantidad <= minima AND cantidad > 0 (includes stock_bajo: 5, stock_critico: 1)
        # sin_stock: cantidad = 0 (includes stock_sin: 0)
        expect(results).to include(stock_bajo, stock_sin, stock_critico)
        expect(results).not_to include(stock_normal)
      end

      it 'returns items with stock_critico OR con_stock' do
        query = described_class.new(user: usuario, status_stock_ids: ['stock_critico', 'con_stock'])
        results = query.to_a

        # con_stock includes normal, bajo, and critico (if > 0)
        # stock_critico includes critico and sin (0 units)
        # Combined: all stocks
        expect(results).to include(stock_normal, stock_bajo, stock_critico, stock_sin)
      end

      it 'handles empty array' do
        query = described_class.new(user: usuario, status_stock_ids: [])
        results = query.to_a

        # Should return all stocks (no filter applied)
        expect(results).to include(stock_normal, stock_bajo, stock_critico, stock_sin)
      end
    end

    context 'when filtering by single status in array format' do
      it 'works with single item array' do
        query = described_class.new(user: usuario, status_stock_ids: ['stock_bajo'])
        results = query.to_a

        expect(results).to include(stock_bajo)
        expect(results).not_to include(stock_normal, stock_sin)
      end
    end
  end

  describe 'busqueda filter' do
    it 'searches by product name' do
      query = described_class.new(user: usuario, busqueda: 'Producto A', solo_categorias_stock_activo: '0')
      results = query.to_a

      expect(results).to include(stock_activo)
      expect(results).not_to include(stock_inactivo)
    end

    it 'searches by product code' do
      producto_activo.update!(codigo: 'ABC123')
      query = described_class.new(user: usuario, busqueda: 'ABC123', solo_categorias_stock_activo: '0')
      results = query.to_a

      expect(results).to include(stock_activo)
    end
  end

  describe 'tienda scoping' do
    let(:otra_tienda) { create(:tienda) }
    let(:categoria_otra) { create(:categoria, tienda: otra_tienda, stock_activo: true) }
    let!(:producto_otra) { create(:producto, tienda: otra_tienda, categoria: categoria_otra) }

    it 'only returns stocks from user tienda' do
      query = described_class.new(user: usuario, solo_categorias_stock_activo: '0')
      results = query.to_a

      expect(results.all? { |s| s.tienda_id == tienda.id }).to be true
    end
  end

  describe 'pagination' do
    it 'supports page method' do
      query = described_class.new(user: usuario, solo_categorias_stock_activo: '0')
      first_page = query.page(1).to_a

      # Just verify pagination works, don't test specific page counts
      expect(first_page).to be_an(Array)
    end
  end
end
