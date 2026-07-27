# frozen_string_literal: true

require 'rails_helper'

# Spec for cart "Ir al Carrito" routing.
#
# Since the opciones step was merged into comprar, both the pedido edit form
# button and the cart dropdown button always route to /comprar.
RSpec.describe 'Cart "Ir al Carrito" routing', :js, type: :system do
  let!(:tienda) do
    create(:tienda,
           nombre: 'Cart Routing Store',
           dominio: 'localhost',
           carrito_de_compras: true,
           horarios_de_entrega: false,
           maneja_stock: false)
  end

  let!(:local) { create(:local, tienda: tienda, nombre: 'Local CR', domicilio: 'Calle CR 1', telefono: '000') }

  let!(:cliente) do
    create(:cliente,
           tienda: tienda,
           nombre: 'Elige Cuenta Cliente',
           cuenta_corriente: false,
           horarios_de_entrega: false,
           usuario_puede_elegir_cuenta: true,
           permitir_envios_a_domicilio: false)
  end

  let!(:cuenta)  { create(:cuenta, nombre: 'Cuenta CR A', cliente: cliente, cuenta_corriente_parcial: nil) }
  let!(:cuenta2) { create(:cuenta, nombre: 'Cuenta CR B', cliente: cliente, cuenta_corriente_parcial: nil) }

  let!(:usuario) do
    create(:usuario, :cliente,
           login: 'cart_routing_user',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Cart Routing User',
           email: 'cart_routing@test.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:categoria) { create(:categoria, nombre: 'CR Cat', tienda: tienda, stock_activo: false) }
  let!(:producto)  { create(:producto, nombre: 'CR Producto', tienda: tienda, categoria: categoria) }

  let(:fecha_valida) do
    d = Date.current + 1.day
    d += 1.day while d.saturday? || d.sunday?
    d
  end

  let!(:pedido) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: fecha_valida, autor: usuario, usuario: usuario)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    create(:producto_solicitado, pedido: p, producto: producto, cantidad: 1, precio_unitario: 50.0)
    p
  end

  before do
    create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 50, fecha_desde: Time.zone.today)
    driven_by :selenium_remote
    cliente_login(usuario)
  end

  it 'pedido form button routes to /comprar' do
    visit edit_pedido_path(pedido)

    form_btn = find('#boton-compra .boton-aceptar-pedido', wait: 5)
    expect(form_btn['href']).to include('/comprar')
  end

  it 'cart dropdown "Ir al Carrito" button routes to /comprar' do
    visit edit_pedido_path(pedido)

    cart_btn = find('#pedido-en-curso .boton-aceptar-pedido', visible: false, wait: 5)
    expect(cart_btn['href']).to include('/comprar')
  end

  it 'clicking cart dropdown button navigates to the comprar page' do
    visit edit_pedido_path(pedido)

    find('#cachincachin').click
    cart_btn = find('#pedido-en-curso .boton-aceptar-pedido', visible: true, wait: 10)
    page.execute_script("window.location.href = arguments[0].getAttribute('href')", cart_btn.native)

    expect(page).to have_current_path(pedido_comprar_path(pedido), wait: 10)
  end

  it 'visiting the legacy /opciones URL redirects to /comprar' do
    visit pedido_opciones_path(pedido)
    expect(page).to have_current_path(pedido_comprar_path(pedido), wait: 10)
  end

  context 'when cliente does NOT need opciones-like screen' do
    before do
      cliente.update_columns(
        usuario_puede_elegir_cuenta: false,
        permitir_envios_a_domicilio: false
      )
      tienda.update_column(:horarios_de_entrega, false)
    end

    it 'cart dropdown button still routes to /comprar' do
      visit edit_pedido_path(pedido)

      cart_btn = find('#pedido-en-curso .boton-aceptar-pedido', visible: false, wait: 5)
      expect(cart_btn['href']).to include('/comprar')
    end
  end
end
