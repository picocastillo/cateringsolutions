require 'rails_helper'

RSpec.describe 'Productos::Stocks', type: :request do
  let(:tienda) { create(:tienda, nombre: 'Test Store', maneja_stock: true) }
  let(:admin_user) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let(:categoria) { create(:categoria, tienda: tienda, stock_activo: true) }
  let!(:producto) { create(:producto, tienda: tienda, categoria: categoria) }
  let(:stock) { producto.stocks.first || producto.stocks.reload.first }

  before do
    admin_user.tiendas << tienda unless admin_user.tiendas.include?(tienda)
    login_as(admin_user)
  end

  describe 'GET /stocks' do
    it 'returns http success' do
      get '/stocks'
      expect(response).to have_http_status(:success)
    end

    it 'filters by solo_categorias_stock_activo by default' do
      categoria_sin_stock = create(:categoria, tienda: tienda, stock_activo: false)
      producto_sin_stock = create(:producto, tienda: tienda, categoria: categoria_sin_stock)

      get '/stocks'
      expect(response.body).to include(producto.nombre)
      expect(response.body).not_to include(producto_sin_stock.nombre)
    end

    it 'shows all stocks when filter is disabled' do
      categoria_sin_stock = create(:categoria, tienda: tienda, stock_activo: false)
      producto_sin_stock = create(:producto, tienda: tienda, categoria: categoria_sin_stock)
      # Manually create stock since categoria has stock_activo: false
      Productos::Stock.create!(
        producto: producto_sin_stock,
        tienda: tienda,
        local_id: nil,
        cantidad_actual: 10,
        cantidad_minima: 5,
        activo: true
      )

      get '/stocks', params: { q: { solo_categorias_stock_activo: '0' } }
      expect(response.body).to include(producto.nombre)
      expect(response.body).to include(producto_sin_stock.nombre)
    end
  end

  describe 'GET /stocks/:id' do
    it 'returns http success' do
      get "/stocks/#{stock.id}"
      expect(response).to have_http_status(:success)
    end

    it 'displays stock information' do
      stock.update!(cantidad_actual: 25, cantidad_minima: 10)
      get "/stocks/#{stock.id}"
      expect(response.body).to include('25')
      expect(response.body).to include('10')
    end
  end

  describe 'GET /stocks/:id/edit' do
    it 'returns http success' do
      get "/stocks/#{stock.id}/edit"
      expect(response).to have_http_status(:success)
    end

    it 'shows the edit form' do
      get "/stocks/#{stock.id}/edit"
      expect(response.body).to include('Editar Stock')
      expect(response.body).to include(producto.nombre)
    end
  end

  describe 'PUT /stocks/:id' do
    context 'with valid parameters' do
      it 'updates the stock (except cantidad_actual which requires ajustar_stock)' do
        put "/stocks/#{stock.id}", params: {
          stock: {
            cantidad_minima: '15',
            cantidad_maxima: '200',
            observaciones: 'Test update',
            activo: '1'
          }
        }

        stock.reload
        # cantidad_actual is NOT updatable via PUT - must use ajustar_stock action
        expect(stock.cantidad_minima).to eq(15.0)
        expect(stock.cantidad_maxima).to eq(200.0)
        expect(stock.observaciones).to eq('Test update')
        expect(stock.activo).to be true
      end

      it 'redirects to show page with success message' do
        put "/stocks/#{stock.id}", params: {
          stock: { cantidad_minima: '15' }
        }

        expect(response).to redirect_to(stock_path(stock))
        follow_redirect!
        expect(response.body).to include('Stock actualizado correctamente')
      end
    end

    context 'with productos_stock parameter key (backward compatibility)' do
      it 'updates the stock' do
        put "/stocks/#{stock.id}", params: {
          productos_stock: {
            cantidad_minima: '20',
            cantidad_maxima: '150'
          }
        }

        stock.reload
        expect(stock.cantidad_minima).to eq(20.0)
        expect(stock.cantidad_maxima).to eq(150.0)
      end
    end

    context 'with invalid parameters' do
      it 'renders edit template' do
        allow_any_instance_of(Productos::Stock).to receive(:save).and_return(false)

        put "/stocks/#{stock.id}", params: {
          stock: { cantidad_minima: '-10' }
        }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Editar Stock')
      end
    end
  end

  describe 'PUT /stocks/:id/ajustar_stock' do
    it 'adjusts stock to new quantity' do
      put "/stocks/#{stock.id}/ajustar_stock", params: {
        nueva_cantidad: '75',
        motivo: 'Inventory adjustment'
      }

      stock.reload
      expect(stock.cantidad_actual).to eq(75.0)
      expect(response).to redirect_to(stock_path(stock))
    end

    it 'creates a stock movement record' do
      expect do
        put "/stocks/#{stock.id}/ajustar_stock", params: {
          nueva_cantidad: '75',
          motivo: 'Inventory adjustment'
        }
      end.to change(Productos::StockMovimiento, :count).by(1)

      movement = Productos::StockMovimiento.last
      expect(movement.motivo).to eq('Inventory adjustment')
      expect(movement.cantidad_nueva).to eq(75.0)
    end

    it 'assigns the current user to the stock movement' do
      put "/stocks/#{stock.id}/ajustar_stock", params: {
        nueva_cantidad: '80',
        motivo: 'Manual adjustment'
      }

      movement = Productos::StockMovimiento.last
      expect(movement.usuario).to eq(admin_user)
      expect(movement.motivo).to eq('Manual adjustment')
    end
  end

  describe 'GET /stocks/:id/movimientos' do
    let!(:movimiento) do
      create(:stock_movimiento,
             stock: stock,
             tipo: 'entrada',
             cantidad: 20,
             cantidad_anterior: 10,
             cantidad_nueva: 30,
             motivo: 'Reposición',
             usuario: admin_user)
    end

    it 'returns movements for the stock' do
      get "/stocks/#{stock.id}/movimientos", xhr: true
      expect(response).to have_http_status(:success)
    end

    it 'displays movement information' do
      get "/stocks/#{stock.id}/movimientos", xhr: true
      expect(response.body).to include('Reposición')
      expect(response.body).to include('20')
    end
  end
end
