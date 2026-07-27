# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cupon Pedido Flow', :js, type: :system do
  before do
    Comprobantes::Tipo.find_or_create_by(codigo: 1) do |tipo|
      tipo.desc = 'Factura'
      tipo.clase = 'Ventas::Facturacion::Factura'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    Comprobantes::Tipo.find_or_create_by(codigo: 3) do |tipo|
      tipo.desc = 'Nota de Crédito'
      tipo.clase = 'Ventas::Facturacion::NotaCredito'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    @tienda = create(:tienda,
                     nombre: 'Cupon Flow Store',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'cupon@store.com',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    @cliente = create(:cliente,
                      nombre: 'Cliente Cupon',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: true,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta, nombre: 'Cuenta Cupon', cliente: @cliente)

    @cliente_user = create(:usuario, :cliente,
                           login: 'clientecupon',
                           password: 'password123',
                           password_confirmation: 'password123',
                           nombre: 'Cliente Cupon User',
                           email: 'clientecupon@example.com',
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

    # Use equal prices so discount divides evenly (no rounding issues)
    # 3 items at $600 each = $1800 total
    # $300 discount / 3 = $100 each → $500 per item → total $1500
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

    @cupon = create(:cupon, tienda: @tienda, tipo_descuento: 'importe', importe: 300, codigo: 'TESTCUP1')
  end

  def login_as_cliente
    visit root_path
    fill_in 'username', with: 'clientecupon'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path(%r{/pedidos}, wait: 5)
  end

  def add_products_to_cart
    expect(page).to have_css('.producto-venta', minimum: 2)
    producto1_card = page.all('.producto-venta').find { |card| card.text.include?(@producto1.nombre) }
    producto2_card = page.all('.producto-venta').find { |card| card.text.include?(@producto2.nombre) }

    # Add 2 units of producto1
    2.times do
      within(producto1_card) do
  find('a.mas').click
  sleep 0.5
end
    end

    # Add 1 unit of producto2
    within(producto2_card) do
      find('a.mas').click
    end
  end

  def go_to_comprar
    carrito_button = page.find('a, button', text: /ir al carrito/i, match: :first)
    carrito_button.click
    expect(page).to have_current_path(%r{/pedidos/\d+/comprar}, wait: 5)
  end

  scenario 'Cliente applies cupon on comprar page and sees discounted prices' do
    login_as_cliente
    add_products_to_cart
    go_to_comprar

    # Total: 2*600 + 1*600 = $1800 (Argentine locale: $1.800,00)
    expect(page).to have_content('1.800,00')

    # Cupon input section should be present
    expect(page).to have_css('#cupon_codigo_input')
    expect(page).to have_css('#aplicar_cupon_btn')

    # Apply cupon via AJAX
    fill_in 'cupon_codigo_input', with: 'TESTCUP1'
    find('#aplicar_cupon_btn').click

    # Cupon applied - check visual indicators
    expect(page).to have_content('TESTCUP1', wait: 10)
    expect(page).to have_content('aplicado', wait: 10)
    expect(page).to have_css('#quitar_cupon_btn', wait: 10)
    expect(page).not_to have_css('#cupon_codigo_input')

    # Total should now be $1500 ($1.500,00)
    expect(page).to have_content('1.500,00')

    # Verify in DB
    pedido = Pedidos::Pedido.last
    expect(pedido.cupon).to eq(@cupon)
    expect(pedido.tiene_descuento_cupon?).to be true

    pedido.productos_solicitados.each do |ps|
      expect(ps.precio_con_descuento).to be < ps.precio_unitario
    end
  end

  scenario 'Cliente removes cupon and it becomes reusable' do
    login_as_cliente
    add_products_to_cart
    go_to_comprar

    # Apply cupon
    fill_in 'cupon_codigo_input', with: 'TESTCUP1'
    find('#aplicar_cupon_btn').click

    expect(page).to have_content('TESTCUP1', wait: 10)
    expect(page).to have_css('#quitar_cupon_btn', wait: 10)

    # Remove cupon
    find('#quitar_cupon_btn').click

    # Should show input again
    expect(page).to have_css('#cupon_codigo_input')
    expect(page).to have_css('#aplicar_cupon_btn')
    expect(page).not_to have_css('#quitar_cupon_btn')

    # Total should be back to full price ($1.800,00)
    expect(page).to have_content('1.800,00')

    # Cupon should be vigente again in DB
    expect(@cupon.reload.vigente?).to be true
    expect(@cupon.usado?).to be false

    # Verify pedido has no cupon
    pedido = Pedidos::Pedido.last
    expect(pedido.cupon).to be_nil
  end

  scenario 'Invalid cupon shows error message' do
    login_as_cliente
    add_products_to_cart
    go_to_comprar

    fill_in 'cupon_codigo_input', with: 'INVALIDCODE'
    find('#aplicar_cupon_btn').click

    expect(page).to have_content('inválido', wait: 10)
    expect(page).to have_css('#cupon_codigo_input')
  end

  scenario 'Cliente confirms pedido with cupon and NC is generated' do
    login_as_cliente
    add_products_to_cart
    go_to_comprar

    # Apply cupon
    fill_in 'cupon_codigo_input', with: 'TESTCUP1'
    find('#aplicar_cupon_btn').click

    expect(page).to have_content('TESTCUP1', wait: 10)
    expect(page).to have_content('1.500,00', wait: 10)

    # Confirm purchase
    confirmar_button = page.find('a, button', text: /finalizar compra/i, match: :first)
    confirmar_button.click

    # Wait for redirect after confirmation
    expect(page).not_to have_current_path(%r{/comprar}, wait: 10)
    page_text = page.text

    # Verify pedido was confirmed
    pedido = Pedidos::Pedido.last
    expect(pedido.estado_id).to be >= 2, "Pedido stayed in estado #{pedido.estado_id}. Page text: #{page_text[0..500]}"
    expect(pedido.cupon).to eq(@cupon)

    # Verify factura was created with full prices
    factura = pedido.comprobantes.find_by(type: 'Ventas::Facturacion::Factura')
    expect(factura).to be_present
    factura.renglones.each do |r|
      expect(r.precio_unitario).to be > 0
    end

    # Verify NC was created for discount
    nc = pedido.comprobantes.find_by(type: 'Ventas::Facturacion::NotaCredito')
    expect(nc).to be_present
    expect(nc.cancela_a).to eq(factura)
    nc.renglones.each do |r|
      expect(r.precio_unitario).to be > 0
      expect(r.descripcion).to include('Descuento cupón')
      expect(r.descripcion).to include('TESTCUP1')
    end

    # Verify cupon is marked as used
    expect(@cupon.reload.usado?).to be true
  end

  scenario 'Cannot apply cupon to already used code' do
    # Create a cancelled pedido to mark the cupon as used without polluting the user's active session
    pedido = build(:pedido, tienda: @tienda, cuenta: @cuenta, autor: @cliente_user, usuario: @cliente_user,
                            cupon: @cupon, fecha: Date.current, estado_id: 5)
    pedido.save(validate: false)

    login_as_cliente
    add_products_to_cart
    go_to_comprar

    fill_in 'cupon_codigo_input', with: 'TESTCUP1'
    find('#aplicar_cupon_btn').click

    expect(page).to have_content('inválido', wait: 10)
  end
end
