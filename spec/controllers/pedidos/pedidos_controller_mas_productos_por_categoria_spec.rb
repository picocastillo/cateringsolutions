require 'rails_helper'

# Tests for tienda.muestra_mas_productos_por_categoria override flag and
# categoria.vender_en_carrito flag.
RSpec.describe Pedidos::PedidosController, type: :controller do
  let(:cliente) { create(:cliente, tienda: tienda, horario_corte_pedidos: '12:00', cuenta_corriente: true) }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:usuario) do
    create(:usuario, :admin, cuenta: cuenta, tienda_cliente: tienda, visualizando_tienda: tienda).tap do |u|
      u.tiendas << tienda unless u.tiendas.include?(tienda)
    end
  end

  let!(:cat_visible) { create(:categoria, nombre: 'EnCarrito', tienda: tienda, vender_en_carrito: true) }
  let!(:cat_oculta)  { create(:categoria, nombre: 'NoEnCarrito', tienda: tienda, vender_en_carrito: false) }
  let!(:prod_visible) { create(:producto, :with_price, tienda: tienda, categoria: cat_visible) }
  let!(:prod_oculto)  { create(:producto, :with_price, tienda: tienda, categoria: cat_oculta) }
  let!(:pedido) do
    create(:pedido, tienda: tienda, cuenta: cuenta, usuario: usuario, autor: usuario,
                    estado_id: 1, fecha: Date.current)
  end

  before do
    allow(controller).to receive_messages(tienda_activa: tienda, current_user: usuario)
  end

  context 'when tienda.muestra_mas_productos_por_categoria is true' do
    let(:tienda) do
      create(:tienda, carrito_de_compras: true,
                      muestra_mas_productos: true,
                      muestra_mas_productos_por_categoria: true)
    end

    describe 'GET #edit' do
      it 'restricts @categorias_disponibles to vender_en_carrito = true categorias' do
        get :edit, params: { id: pedido.id }

        expect(response).to have_http_status(:success)
        cats = assigns(:categorias_disponibles)
        expect(cats).to include(cat_visible)
        expect(cats).not_to include(cat_oculta)
      end
    end

    describe 'POST #cambiar_categoria' do
      it 'restricts @prs precios to productos in vender_en_carrito categorias' do
        post :cambiar_categoria, params: { id: pedido.id }, format: :js

        expect(response).to have_http_status(:success)
        prs = assigns(:prs)
        producto_ids = prs.map(&:producto_id)
        expect(producto_ids).to include(prod_visible.id)
        expect(producto_ids).not_to include(prod_oculto.id)
      end
    end
  end

  context 'when only tienda.muestra_mas_productos is true (legacy behaviour)' do
    let(:tienda) do
      create(:tienda, carrito_de_compras: true,
                      muestra_mas_productos: true,
                      muestra_mas_productos_por_categoria: false)
    end

    describe 'GET #edit' do
      it 'includes ALL categorias regardless of vender_en_carrito flag' do
        get :edit, params: { id: pedido.id }

        cats = assigns(:categorias_disponibles)
        expect(cats).to include(cat_visible, cat_oculta)
      end
    end

    describe 'POST #cambiar_categoria' do
      it 'includes precios for ALL productos regardless of vender_en_carrito' do
        post :cambiar_categoria, params: { id: pedido.id }, format: :js

        prs = assigns(:prs)
        producto_ids = prs.map(&:producto_id)
        expect(producto_ids).to include(prod_visible.id, prod_oculto.id)
      end
    end
  end

  context 'when muestra_mas_productos_por_categoria is true but NO category has vender_en_carrito=true' do
    let(:tienda) do
      create(:tienda, carrito_de_compras: true,
                      muestra_mas_productos: true,
                      muestra_mas_productos_por_categoria: true)
    end

    before { [cat_visible, cat_oculta].each { |c| c.update_column(:vender_en_carrito, false) } }

    describe 'GET #edit' do
      it 'sets @categorias_disponibles to empty (hides the panel in the view)' do
        get :edit, params: { id: pedido.id }

        expect(assigns(:categorias_disponibles).to_a).to be_empty
      end
    end

    describe 'POST #cambiar_categoria' do
      it 'returns no products (not all products)' do
        post :cambiar_categoria, params: { id: pedido.id }, format: :js

        prs = assigns(:prs)
        expect(prs.to_a).to be_empty
      end
    end
  end
end
