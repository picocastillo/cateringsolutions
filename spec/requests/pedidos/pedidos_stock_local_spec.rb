require 'rails_helper'

# Tests that stock validation in the pedidos controller uses the pedido's local_id,
# not just nil (main stock). This ensures multi-local tiendas check the correct
# local-specific stock when validating availability.

RSpec.describe 'Pedidos Stock Validation with local_id', type: :request do
  let(:tienda) { create(:tienda, nombre: 'Multi Local Store', maneja_stock: true, multiple_locales: true, carrito_de_compras: true) }
  let(:local_a) { create(:local, tienda: tienda, nombre: 'Local A') }
  let(:local_b) { create(:local, tienda: tienda, nombre: 'Local B') }
  let(:categoria) { create(:categoria, tienda: tienda, stock_activo: true) }
  let(:producto) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Producto Multi-Local') }
  let(:cliente) { create(:cliente, tienda: tienda, cuenta_corriente: true) }
  let(:cuenta) { create(:cuenta, cliente: cliente, cuenta_corriente_parcial: true) }
  let(:admin_user) do
    # Force locals to exist before user creation (multi-locale tienda requires local)
    local_a
    local_b
    u = create(:usuario, :admin, visualizando_tienda: tienda, local: local_a)
    u
  end

  let(:valid_fecha) do
    d = Time.zone.today + 1
    d += 1 while d.saturday? || d.sunday?
    d
  end

  before do
    admin_user.tiendas << tienda unless admin_user.tiendas.include?(tienda)
    login_as(admin_user)
  end

  describe 'stock validation checks the correct local' do
    before do
      # Local A has plenty of stock
      Productos::Stock.find_or_create_by!(producto: producto, tienda: tienda, local: local_a) do |s|
        s.cantidad_actual = 50
        s.cantidad_minima = 5
      end.update!(cantidad_actual: 50)

      # Local B has NO stock
      Productos::Stock.find_or_create_by!(producto: producto, tienda: tienda, local: local_b) do |s|
        s.cantidad_actual = 0
        s.cantidad_minima = 5
      end.update!(cantidad_actual: 0)

      # Main stock (nil local) has plenty
      Productos::Stock.find_or_create_by!(producto: producto, tienda: tienda, local_id: nil) do |s|
        s.cantidad_actual = 100
        s.cantidad_minima = 5
      end.update!(cantidad_actual: 100)
    end

    context 'pedido assigned to local_a (has stock)' do
      let(:pedido) do
        p = build(:pedido, tienda: tienda, cuenta: cuenta, usuario: admin_user,
                           autor: admin_user, local: local_a, fecha: valid_fecha, estado_id: 1)
        p.asignar_cuenta_manual
        p.cuenta = cuenta
        p.save!
        p
      end

      before do
        ps = Productos::ProductoSolicitado.new(
          pedido: pedido, producto: producto, cantidad: 10, precio_unitario: 100
        )
        ps.save(validate: false)
      end

      it 'passes stock validation when local has sufficient stock' do
        post finalizar_pedido_path(pedido)

        # Should NOT get 403 (user is authorized)
        expect(response.status).not_to eq(403)
        # Should NOT redirect to comprar (stock is sufficient at local_a)
        expect(response).not_to redirect_to(pedido_comprar_path(pedido))
      end
    end

    context 'pedido assigned to local_b (no stock)' do
      let(:pedido) do
        p = build(:pedido, tienda: tienda, cuenta: cuenta, usuario: admin_user,
                           autor: admin_user, local: local_b, fecha: valid_fecha, estado_id: 1)
        p.asignar_cuenta_manual
        p.cuenta = cuenta
        p.save!
        p
      end

      before do
        ps = Productos::ProductoSolicitado.new(
          pedido: pedido, producto: producto, cantidad: 10, precio_unitario: 100
        )
        ps.save(validate: false)
      end

      it 'fails stock validation when local has no stock (even if main stock has plenty)' do
        post finalizar_pedido_path(pedido)

        # Should redirect to comprar because local_b has 0 stock
        expect(response).to redirect_to(pedido_comprar_path(pedido))
        expect(flash[:warning]).to include('sin stock')
      end
    end
  end

  describe 'GET show - stock warnings use local_id' do
    let(:pedido) do
      p = build(:pedido, tienda: tienda, cuenta: cuenta, usuario: admin_user,
                         autor: admin_user, local: local_b, fecha: valid_fecha, estado_id: 1)
      p.asignar_cuenta_manual
      p.cuenta = cuenta
      p.save!
      p
    end

    before do
      # Local B has no stock, main stock has plenty
      Productos::Stock.find_or_create_by!(producto: producto, tienda: tienda, local: local_b) do |s|
        s.cantidad_actual = 0
        s.cantidad_minima = 5
      end.update!(cantidad_actual: 0)

      Productos::Stock.find_or_create_by!(producto: producto, tienda: tienda, local_id: nil) do |s|
        s.cantidad_actual = 100
        s.cantidad_minima = 5
      end.update!(cantidad_actual: 100)

      ps = Productos::ProductoSolicitado.new(
        pedido: pedido, producto: producto, cantidad: 5, precio_unitario: 100
      )
      ps.save(validate: false)
    end

    it 'shows stock warning for the correct local' do
      get pedido_path(pedido)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('sin stock')
    end
  end
end
