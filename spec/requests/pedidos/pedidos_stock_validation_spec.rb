# Request Spec: Pedidos Stock Validation in Checkout (finalizar action)
#
# This spec documents that stock checking happens in the POST finalizar action,
# not in GET comprar. When stock is insufficient, the user is redirected back to
# the checkout screen (/pedidos/:id/comprar) with flash messages showing which
# products have stock issues.
#
# Controller Behavior:
# - GET comprar: Shows checkout screen, reads @productos_sin_stock from flash if present
# - POST finalizar: Validates stock BEFORE calling aceptar, redirects back if issues found
#
# Flash Structure:
# - flash[:warning]: User-friendly message about stock issues
# - flash[:productos_sin_stock]: Array of hashes with {:producto, :solicitado, :disponible}
#
# View Behavior:
# - show.html.erb displays stock warning alert when @productos_sin_stock is present
# - Alert shows detailed breakdown of each product with insufficient stock
#
# Note: The actual stock validation logic is tested in spec/models/pedidos/pedido_spec.rb
# This spec is kept minimal to document the controller-level behavior.

require 'rails_helper'

RSpec.describe 'Pedidos Stock Validation', type: :request do
  let(:tienda) { create(:tienda, nombre: 'Test Store', carrito_de_compras: true) }
  let(:local) { create(:local, tienda: tienda, nombre: 'Local Principal', domicilio: 'Test 123', telefono: '123456') }
  let(:categoria_con_stock) { create(:categoria, tienda: tienda, stock_activo: true) }
  let(:producto_con_stock) { create(:producto, tienda: tienda, categoria: categoria_con_stock, nombre: 'Producto A') }
  let(:cliente) { create(:cliente, tienda: tienda, cuenta_corriente: true) }
  let(:cuenta) { create(:cuenta, cliente: cliente, cuenta_corriente_parcial: true) }
  let(:admin_user) { create(:usuario, :admin, visualizando_tienda: tienda) }

  let!(:stock_con_producto) do
    Productos::Stock.create!(
      producto: producto_con_stock,
      tienda: tienda,
      local: local,
      cantidad_actual: 10,
      cantidad_minima: 2
    )
  end

  let(:valid_fecha) do
    d = Time.zone.today + 1
    d += 1 while d.saturday? || d.sunday?
    d
  end

  let(:pedido) do
    p = create(:pedido,
               tienda: tienda,
               cuenta: cuenta,
               usuario: admin_user,
               autor: admin_user,
               local: local,
               fecha: valid_fecha,
               estado_id: Pedidos::Estado[:pendiente].id)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    p
  end

  before do
    admin_user.tiendas << tienda unless admin_user.tiendas.include?(tienda)
    login_as(admin_user)
  end

  describe 'Stock validation in finalizar action' do
    context 'when stock is sufficient' do
      before do
        ps = Productos::ProductoSolicitado.new(
          pedido: pedido,
          producto: producto_con_stock,
          cantidad: 5,
          precio_unitario: 100
        )
        ps.save(validate: false)
      end

      it 'accepts the pedido and does not redirect to comprar' do
        post finalizar_pedido_path(pedido)

        expect(response).not_to redirect_to(pedido_comprar_path(pedido))
        expect(flash[:warning]).to be_nil
      end
    end

    context 'when stock is insufficient' do
      before do
        ps = Productos::ProductoSolicitado.new(
          pedido: pedido,
          producto: producto_con_stock,
          cantidad: 15,
          precio_unitario: 100
        )
        ps.save(validate: false)
      end

      it 'redirects back to checkout with stock warning' do
        post finalizar_pedido_path(pedido)

        expect(response).to redirect_to(pedido_comprar_path(pedido))
        follow_redirect!

        expect(response.body).to include('sin stock o tienen stock insuficiente')
        expect(assigns(:productos_sin_stock)).to be_present
      end
    end
  end

  describe 'GET comprar' do
    it 'initializes productos_sin_stock from flash' do
      get pedido_comprar_path(pedido)

      expect(response).to have_http_status(:success)
      expect(assigns(:productos_sin_stock)).to eq([])
    end
  end
end
