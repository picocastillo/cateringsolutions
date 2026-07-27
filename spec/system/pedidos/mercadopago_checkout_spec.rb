# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MercadoPago Checkout Flow', :js, type: :system do
  before do
    # Stub MercadoPago SDK so tests don't depend on external API credentials
    mp_preference = double('preference')
    allow(mp_preference).to receive(:create).and_return(
      { response: { 'id' => 'TEST-fake-preference-id-12345' } }
    )
    mp_sdk = double('sdk', preference: mp_preference)
    allow(Mercadopago::SDK).to receive(:new).and_return(mp_sdk)

    @tienda = create(:tienda,
                     nombre: 'MP Checkout Store',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'mp@checkout.com',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    # Cliente WITHOUT cuenta_corriente and without opciones
    # This means: no opciones step, goes directly to comprar page
    # where MercadoPago payment is triggered automatically
    @cliente = create(:cliente,
                      nombre: 'Cliente MP Checkout',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: false,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta, nombre: 'Cuenta MP Checkout', cliente: @cliente, cuenta_corriente_parcial: nil)

    @cliente_user = create(:usuario, :cliente,
                           login: 'clientecheckout',
                           password: 'password123',
                           password_confirmation: 'password123',
                           nombre: 'MP Checkout User',
                           email: 'mpcheckout@example.com',
                           cuenta: @cuenta,
                           tienda_cliente: @tienda,
                           visualizando_tienda: @tienda)

    @categoria = create(:categoria,
                        nombre: 'Comidas',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    # Required dummy daily menu category (avoids empty array SQL issue)
    create(:categoria, nombre: 'Menu Diario Dummy', tienda: @tienda, menu_diario: true)

    @cliente.categorias << @categoria unless @cliente.categorias.include?(@categoria)

    @producto1 = create(:producto,
                        nombre: 'Milanesa Napolitana',
                        codigo: 'MIL001',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    @producto2 = create(:producto,
                        nombre: 'Ensalada César',
                        codigo: 'ENS001',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    create(:precio, producto: @producto1, importe: 2500.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    create(:precio, producto: @producto2, importe: 1800.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def login_as_cliente
    visit root_path
    fill_in 'username', with: 'clientecheckout'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path(%r{/pedidos}, wait: 5)
  end

  def add_products_to_cart
    expect(page).to have_css('.producto-venta', minimum: 2)

    producto1_card = page.all('.producto-venta').find { |card| card.text.include?(@producto1.nombre) }
    producto2_card = page.all('.producto-venta').find { |card| card.text.include?(@producto2.nombre) }

    within(producto1_card) do
      find('a.mas').click
      sleep 0.5
    end

    within(producto2_card) do
      find('a.mas').click
      sleep 0.5
    end
  end

  scenario 'Cliente without cuenta corriente sees MercadoPago payment on checkout' do
    login_as_cliente
    add_products_to_cart

    # "Ir al Carrito" should link directly to comprar (no opciones step)
    carrito_link = page.find('a', text: /ir al carrito/i, match: :first)
    expect(carrito_link[:href]).to match(%r{/pedidos/\d+/comprar})

    carrito_link.click
    expect(page).to have_current_path(%r{/pedidos/\d+/comprar}, wait: 5)

    # Should show Checkout title
    expect(page).to have_content('Checkout')

    # Should NOT show "Finalizar Compra" (that's for cuenta corriente)
    expect(page).not_to have_css('#confirmar_pedido')

    # preference-container should be present (triggers AJAX to generar_pago_ml)
    expect(page).to have_css('#preference-container')

    # Wait for generar_pago_ml AJAX to complete and render the MP button
    expect(page).to have_css('#mp-boton-container', wait: 15)

    # Verify the MP button was rendered with the stubbed preference ID
    mp_container = find('#mp-boton-container')
    preference_id = mp_container['data-pid']
    expect(preference_id).to eq('TEST-fake-preference-id-12345')

    # Verify the public key is set for the MercadoPago SDK
    public_key = mp_container['data-pk']
    expect(public_key).to be_present

    # Wait for MercadoPago SDK to load from CDN
    sleep 3

    # Verify the MercadoPago SDK loaded from CDN and is available for checkout
    mp_defined = page.evaluate_script('typeof MercadoPago !== "undefined"')
    expect(mp_defined).to be true
  end
end
