# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cupon MercadoPago Flow', :js, type: :system do
  before do
    @tienda = create(:tienda,
                     nombre: 'MP Cupon Store',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'mp@store.com',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    @cliente = create(:cliente,
                      nombre: 'Cliente MP',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: true,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: false,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta, nombre: 'Cuenta MP', cliente: @cliente, cuenta_corriente_parcial: nil)

    @cliente_user = create(:usuario, :cliente,
                           login: 'clientemp',
                           password: 'password123',
                           password_confirmation: 'password123',
                           nombre: 'Cliente MP User',
                           email: 'clientemp@example.com',
                           cuenta: @cuenta,
                           tienda_cliente: @tienda,
                           visualizando_tienda: @tienda)

    @categoria = create(:categoria,
                        nombre: 'Viandas',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria, nombre: 'Menu Diario Dummy', tienda: @tienda, menu_diario: true)

    @cliente.categorias << @categoria unless @cliente.categorias.include?(@categoria)

    @producto1 = create(:producto,
                        nombre: 'Menú Clásico',
                        codigo: 'MEN001',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    @producto2 = create(:producto,
                        nombre: 'Menú Premium',
                        codigo: 'MEN002',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    create(:precio, producto: @producto1, importe: 600.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    create(:precio, producto: @producto2, importe: 600.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)

    @cupon = create(:cupon, tienda: @tienda, tipo_descuento: 'importe', importe: 300, codigo: 'MPCUP1')
  end

  def login_as_cliente
    visit root_path
    fill_in 'username', with: 'clientemp'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path(%r{/pedidos}, wait: 5)
  end

  def add_products_to_cart
    expect(page).to have_css('.producto-venta', minimum: 2)
    producto1_card = page.all('.producto-venta').find { |card| card.text.include?(@producto1.nombre) }
    producto2_card = page.all('.producto-venta').find { |card| card.text.include?(@producto2.nombre) }

    2.times do
      within(producto1_card) do
  find('a.mas').click
  sleep 0.5
end
    end

    within(producto2_card) do
      find('a.mas').click
    end
  end

  def go_to_comprar
    carrito_button = page.find('a, button', text: /ir al carrito/i, match: :first)
    carrito_button.click
    expect(page).to have_current_path(%r{/pedidos/\d+/comprar}, wait: 5)
  end

  scenario 'MercadoPago client sees cupon section on comprar page' do
    login_as_cliente
    add_products_to_cart
    go_to_comprar

    # Total: 2*600 + 1*600 = $1800
    expect(page).to have_content('1.800,00')

    # Cupon input should be present on comprar page
    expect(page).to have_css('#cupon_codigo_input')
    expect(page).to have_css('#aplicar_cupon_btn')

    # Enviar a dropdown should be present (usuario_puede_elegir_cuenta)
    expect(page).to have_content('Enviar a')

    # MercadoPago preference container should be present
    expect(page).to have_css('#preference-container')
  end

  scenario 'Applies cupon on comprar page and sees discounted prices' do
    login_as_cliente
    add_products_to_cart
    go_to_comprar

    expect(page).to have_content('1.800,00')

    # Apply cupon via AJAX
    fill_in 'cupon_codigo_input', with: 'MPCUP1'
    find('#aplicar_cupon_btn').click

    # Page reloads after cupon apply
    expect(page).to have_content('MPCUP1')
    expect(page).to have_content('aplicado')
    expect(page).to have_css('#quitar_cupon_btn')
    expect(page).not_to have_css('#cupon_codigo_input')

    # Total should be $1500
    expect(page).to have_content('1.500,00')

    # Verify in DB
    pedido = Pedidos::Pedido.last
    expect(pedido.cupon).to eq(@cupon)
    expect(pedido.tiene_descuento_cupon?).to be true
  end

  scenario 'Removes cupon on comprar page' do
    login_as_cliente
    add_products_to_cart
    go_to_comprar

    # Apply cupon
    fill_in 'cupon_codigo_input', with: 'MPCUP1'
    find('#aplicar_cupon_btn').click

    expect(page).to have_css('#quitar_cupon_btn')

    # Remove cupon
    find('#quitar_cupon_btn').click

    # Should show input again
    expect(page).to have_css('#cupon_codigo_input')
    expect(page).not_to have_css('#quitar_cupon_btn')

    # Total should be back to $1800
    expect(page).to have_content('1.800,00')

    # Cupon should be vigente again
    expect(@cupon.reload.vigente?).to be true
  end

  scenario 'Cupon persists on comprar page with MercadoPago preference' do
    login_as_cliente
    add_products_to_cart
    go_to_comprar

    # Apply cupon
    fill_in 'cupon_codigo_input', with: 'MPCUP1'
    find('#aplicar_cupon_btn').click

    expect(page).to have_content('MPCUP1')
    expect(page).to have_content('1.500,00')

    # Cupon stays applied on comprar
    expect(page).to have_content('aplicado')

    # MercadoPago button should appear
    expect(page).to have_css('#preference-container')
  end

  scenario 'Invalid cupon shows error on comprar page' do
    login_as_cliente
    add_products_to_cart
    go_to_comprar

    fill_in 'cupon_codigo_input', with: 'INVALIDCODE'
    find('#aplicar_cupon_btn').click

    expect(page).to have_content('inválido')
    expect(page).to have_css('#cupon_codigo_input')
  end

  scenario 'Cliente without turnos sees no turno selector on comprar' do
    login_as_cliente
    add_products_to_cart
    go_to_comprar

    # No turno selector should appear (cliente has no turnos)
    expect(page).not_to have_css('#turno_entrega_selector')

    # MercadoPago preference is generated (no turno required)
    expect(page).to have_css('#preference-container', wait: 5)
  end
end
