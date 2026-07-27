# frozen_string_literal: true

require 'rails_helper'

# Covers: checkout page warnings that block finalizar.
#
#   1. Stock warning: when a product has insufficient stock, the comprar page shows
#      the warning panel with the product name and "Modificar pedido" link.
#   2. Limit-exceeded warning: when the pedido total exceeds cliente.limite_compra_pesos,
#      the "Finalizar Compra" button is hidden and the warning is shown.
#   3. Happy path: with sufficient stock and no limit, "Finalizar Compra" is shown.

RSpec.describe 'Checkout page warnings (stock & limite de compra)', :js, type: :system do
  before do
    Comprobantes::Tipo.find_or_create_by(codigo: 1) do |t|
      t.desc = 'Factura'
      t.clase = 'Ventas::Facturacion::Factura'
      t.letra = 'A'
      t.debitan = false
    end
    Comprobantes::Tipo.find_or_create_by(codigo: 3) do |t|
      t.desc = 'Nota de Crédito'
      t.clase = 'Ventas::Facturacion::NotaCredito'
      t.letra = 'A'
      t.debitan = false
    end

    @tienda = create(:tienda,
                     nombre: 'Warnings Store',
                     dominio: 'localhost',
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: true)

    @cliente = create(:cliente,
                      nombre: 'Cliente Warnings',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: true,
                      listas_de_precio_privada: false,
                      limite_compra_pesos: nil)

    @cuenta = create(:cuenta, nombre: 'Cuenta Warnings', cliente: @cliente,
                              cuenta_corriente_parcial: true)

    @usuario = create(:usuario, :cliente,
                      login: 'warnings_user',
                      password: 'password123',
                      password_confirmation: 'password123',
                      nombre: 'Warnings User',
                      email: 'warnings@test.com',
                      cuenta: @cuenta,
                      tienda_cliente: @tienda,
                      visualizando_tienda: @tienda)

    @categoria = create(:categoria, nombre: 'Cat Warnings', tienda: @tienda,
                                    stock_activo: true, menu_diario: false)
    create(:categoria, nombre: 'Menu Dummy Warn', tienda: @tienda, menu_diario: true)
    @cliente.categorias << @categoria

    @producto = create(:producto, nombre: 'Producto Stock Warning', tienda: @tienda,
                                  categoria: @categoria)

    @stock = @producto.stocks.find_or_create_by!(tienda: @tienda, local_id: nil)
    @stock.update!(cantidad_actual: 10, cantidad_minima: 2, activo: true)

    create(:precio, :for_cliente, producto: @producto, cliente: @cliente, importe: 200,
                                  fecha_desde: Time.zone.today)

    driven_by :selenium_remote
    visit root_path
    fill_in 'username', with: 'warnings_user'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    page.assert_current_path(%r{/pedidos}, wait: 10)
  end

  let(:fecha) do
    d = Date.current + 1.day
    d += 1.day while d.saturday? || d.sunday?
    d
  end

  def build_pedido(cantidad:)
    p = build(:pedido, tienda: @tienda, cuenta: @cuenta, usuario: @usuario,
                       estado_id: 1, fecha: fecha, autor: @usuario)
    p.asignar_cuenta_manual
    p.cuenta = @cuenta
    p.save!
    create(:producto_solicitado, pedido: p, producto: @producto, cantidad: cantidad,
                                 precio_unitario: 200.0)
    p
  end

  # ─── 1. Stock warning ──────────────────────────────────────────────────────

  describe 'insufficient stock' do
    it 'shows stock warning panel on the comprar page' do
      @stock.update!(cantidad_actual: 2)
      pedido = build_pedido(cantidad: 5)

      visit pedido_comprar_path(pedido)
      expect(page).to have_css('#show-pedido', wait: 15)

      # Warning panel present
      expect(page).to have_css('.alert.alert-warning', wait: 10)
      expect(page).to have_content(@producto.nombre)
      expect(page).to have_content('sin stock o con stock insuficiente')
    end

    it 'shows the flash warning message' do
      @stock.update!(cantidad_actual: 2)
      pedido = build_pedido(cantidad: 5)

      visit pedido_comprar_path(pedido)

      expect(page).to have_content(/sin stock|stock insuficiente/i, wait: 10)
    end

    it 'still shows the Finalizar Compra button (blocked by finalizar action server-side)' do
      @stock.update!(cantidad_actual: 2)
      pedido = build_pedido(cantidad: 5)

      visit pedido_comprar_path(pedido)
      expect(page).to have_css('#show-pedido', wait: 15)

      # CC flow does NOT hide the button on stock warning — the server blocks finalizar instead
      expect(page).to have_css('#confirmar_pedido', wait: 5)
    end
  end

  # ─── 2. Limite de compra ───────────────────────────────────────────────────

  describe 'purchase limit exceeded' do
    it 'shows the limite warning on the comprar page' do
      # Set limit to $100, product costs $200 → exceeds limit
      @cliente.update!(limite_compra_pesos: 100.0)
      pedido = build_pedido(cantidad: 1)

      visit pedido_comprar_path(pedido)
      expect(page).to have_css('#show-pedido', wait: 15)

      expect(page).to have_content(/límite.*compra|límite diario/i, wait: 10)
    end

    it 'hides the Finalizar Compra button when limit is exceeded' do
      @cliente.update!(limite_compra_pesos: 100.0)
      pedido = build_pedido(cantidad: 1)

      visit pedido_comprar_path(pedido)
      expect(page).to have_css('#show-pedido', wait: 15)

      expect(page).not_to have_css('#confirmar_pedido', wait: 5)
    end

    it 'shows Finalizar Compra when total is within limit' do
      @cliente.update!(limite_compra_pesos: 1000.0)
      pedido = build_pedido(cantidad: 1) # $200 < $1000 limit

      visit pedido_comprar_path(pedido)
      expect(page).to have_css('#confirmar_pedido', wait: 15)

      expect(page).not_to have_content(/supera el límite/i, wait: 2)
    end
  end

  # ─── 3. Happy path ─────────────────────────────────────────────────────────

  describe 'happy path — sufficient stock, no limit' do
    it 'shows the Finalizar Compra button' do
      pedido = build_pedido(cantidad: 3) # stock=10, limit=nil → OK

      visit pedido_comprar_path(pedido)
      expect(page).to have_css('#confirmar_pedido', wait: 15)
    end
  end
end
