# frozen_string_literal: true

require 'rails_helper'

# Regression test for: MP payment button rendered twice on first visit to comprar.
#
# Root cause: App.onMount('#show-pedido') programmatically called
# $('#pedido_enviar_a_id').change() to initialise DOM visibility. When the client
# has usuario_puede_elegir_cuenta: true, the change handler's else branch called
# patchPedidoAndRefireMp(), which sent a PATCH then refireGenerarPagoMl() — firing
# a SECOND AJAX to generar_pago_ml concurrently with the initial request from
# App.onMount('#show-pedido #preference-container').
#
# Both async co.render() calls then targeted the same '#mp-boton-container' ID
# selector and inserted two MP buttons into the container.
#
# Fix: Replace the programmatic .change() with an inline DOM-only initialisation
# that does not call patchPedidoAndRefireMp, preventing the double request.
RSpec.describe 'MercadoPago button single render', :js, type: :system do
  before do
    @sdk_call_count = 0

    mp_preference = double('preference')
    allow(mp_preference).to receive(:create) do
      @sdk_call_count += 1
      { response: { 'id' => 'TEST-pref-single-render' } }
    end
    mp_sdk = double('sdk', preference: mp_preference)
    allow(Mercadopago::SDK).to receive(:new).and_return(mp_sdk)

    @tienda = create(:tienda,
                     nombre: 'MP Single Render Store',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'single@mp.com',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    # usuario_puede_elegir_cuenta: true is the key condition that causes
    # #pedido_enviar_a_id to appear on the comprar page, triggering the bug.
    @cliente = create(:cliente,
                      nombre: 'Cliente MP Single',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: true,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: false,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta, nombre: 'Cuenta Principal', cliente: @cliente,
                              cuenta_corriente_parcial: nil)
    # Second cuenta so the selector has at least two options to choose from.
    create(:cuenta, nombre: 'Cuenta Alternativa', cliente: @cliente,
                    cuenta_corriente_parcial: nil)

    @user = create(:usuario, :cliente,
                   login: 'mpsinglerenderuser',
                   password: 'password123',
                   password_confirmation: 'password123',
                   nombre: 'MP Single Render User',
                   email: 'mpsingle@example.com',
                   cuenta: @cuenta,
                   tienda_cliente: @tienda,
                   visualizando_tienda: @tienda)

    @categoria = create(:categoria,
                        nombre: 'Platos',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)
    create(:categoria, nombre: 'Menu Diario Dummy', tienda: @tienda, menu_diario: true)
    @cliente.categorias << @categoria unless @cliente.categorias.include?(@categoria)

    @producto = create(:producto,
                       nombre: 'Pollo al Horno',
                       codigo: 'POL001',
                       tienda: @tienda,
                       categoria: @categoria,
                       discontinued_at: nil)
    create(:precio, producto: @producto, importe: 1500.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def login_as_user
    visit root_path
    fill_in 'username', with: 'mpsinglerenderuser'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path(%r{/pedidos}, wait: 5)
  end

  scenario 'generar_pago_ml is called exactly once even when enviar_a selector is present' do
    login_as_user

    # Add a product to the cart.
    expect(page).to have_css('.producto-venta', minimum: 1, wait: 10)
    producto_card = page.all('.producto-venta').find { |c| c.text.include?(@producto.nombre) }
    within(producto_card) { find('a.mas').click }
    sleep 0.5

    # Navigate to the comprar (checkout) page.
    carrito_link = page.find('a', text: /ir al carrito/i, match: :first)
    expect(carrito_link[:href]).to match(%r{/pedidos/\d+/comprar})
    carrito_link.click
    expect(page).to have_current_path(%r{/pedidos/\d+/comprar}, wait: 5)

    # The enviar_a selector must be visible — this is what triggers the bug.
    expect(page).to have_css('#pedido_enviar_a_id', wait: 5)

    # Wait for the initial generar_pago_ml AJAX to complete and the container
    # to appear, then wait for any racing second request to also complete.
    expect(page).to have_css('#mp-boton-container', wait: 15)
    wait_for_ajax
    # Extra pause for any async MP SDK rendering to finish.
    sleep 1

    # The preference should have been created exactly once.
    # Before the fix, patchPedidoAndRefireMp fires a second generar_pago_ml
    # request, so @sdk_call_count would be 2.
    expect(@sdk_call_count).to eq(1),
                               'Expected MP preference to be created once but it was created ' \
                               "#{@sdk_call_count} times. The programmatic #pedido_enviar_a_id " \
                               '.change() triggered patchPedidoAndRefireMp, firing a second ' \
                               'generar_pago_ml AJAX that races with the initial one.'

    # There should be exactly one MP button container in the DOM.
    expect(page).to have_css('#mp-boton-container', count: 1)

    # The disabled placeholder should be gone — replaced by the real container.
    expect(page).not_to have_css('.mercadopago-button-disabled')
  end
end
