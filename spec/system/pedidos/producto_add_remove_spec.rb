# frozen_string_literal: true

require 'rails_helper'

# Covers: product add via + button, quantity increment, decrement, removal on zero,
# and cart total update — the core daily-use flow of the pedido edit page.
RSpec.describe 'Producto add / remove en pedido', :js, type: :system do
  before do
    @tienda = create(:tienda,
                     nombre: 'Add Remove Store',
                     dominio: 'localhost',
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    @cliente = create(:cliente,
                      nombre: 'Cliente Add Remove',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: true,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta, nombre: 'Cuenta Add Remove', cliente: @cliente)

    @user = create(:usuario, :cliente,
                   login: 'useraddrm',
                   password: 'password123',
                   password_confirmation: 'password123',
                   nombre: 'Add Remove User',
                   email: 'addrm@example.com',
                   cuenta: @cuenta,
                   tienda_cliente: @tienda,
                   visualizando_tienda: @tienda)

    @categoria = create(:categoria,
                        nombre: 'Platos',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria, nombre: 'Menu Dummy', tienda: @tienda, menu_diario: true)

    @cliente.categorias << @categoria

    @producto = create(:producto,
                       nombre: 'Milanesa Napolitana',
                       tienda: @tienda,
                       categoria: @categoria)

    @producto2 = create(:producto,
                        nombre: 'Ensalada César',
                        tienda: @tienda,
                        categoria: @categoria)

    create(:precio, producto: @producto,  importe: 500.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    create(:precio, producto: @producto2, importe: 300.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def login
    visit root_path
    fill_in 'username', with: 'useraddrm'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path(%r{/pedidos}, wait: 10)
  end

  def product_card(nombre)
    expect(page).to have_css('.producto-venta', minimum: 1, wait: 10)
    page.all('.producto-venta').find { |c| c.text.include?(nombre) }
  end

  def input_cantidad(producto)
    page.find("#input_cantidad_#{producto.id}")
  end

  scenario 'clicking + once adds the product with quantity 1' do
    login
    expect(page).to have_css('.producto-venta', wait: 10)

    card = product_card(@producto.nombre)
    within(card) { find('a.mas').click }
    sleep 0.8

    expect(input_cantidad(@producto).value.to_i).to eq(1)

    # Product appears in the cart sidebar (may be collapsed but item is in DOM)
    expect(page).to have_css('#pedido-en-curso .item', minimum: 1, wait: 5, visible: :any)

    # Persisted to DB
    pedido = Pedidos::Pedido.last
    ps = pedido.productos_solicitados.find_by(producto_id: @producto.id)
    expect(ps).not_to be_nil
    expect(ps.cantidad).to eq(1)
  end

  scenario 'clicking + multiple times increments the quantity correctly' do
    login
    expect(page).to have_css('.producto-venta', wait: 10)
    card = product_card(@producto.nombre)

    3.times do
      within(card) { find('a.mas').click }
      sleep 0.5
    end

    expect(input_cantidad(@producto).value.to_i).to eq(3)

    ps = Pedidos::Pedido.last.productos_solicitados.find_by(producto_id: @producto.id)
    expect(ps.cantidad).to eq(3)
  end

  scenario 'clicking - decrements the quantity' do
    login
    expect(page).to have_css('.producto-venta', wait: 10)
    card = product_card(@producto.nombre)

    3.times do
  within(card) { find('a.mas').click }
  sleep 0.4
end
    expect(input_cantidad(@producto).value.to_i).to eq(3)

    within(card) { find('a.menos').click }
    sleep 0.6

    expect(input_cantidad(@producto).value.to_i).to eq(2)

    ps = Pedidos::Pedido.last.productos_solicitados.find_by(producto_id: @producto.id)
    expect(ps.cantidad).to eq(2)
  end

  scenario 'decrementing to zero removes the product from the cart' do
    login
    expect(page).to have_css('.producto-venta', wait: 10)
    card = product_card(@producto.nombre)

    within(card) { find('a.mas').click }
    sleep 0.6
    expect(input_cantidad(@producto).value.to_i).to eq(1)

    within(card) { find('a.menos').click }
    sleep 0.8

    # Quantity back to zero in the input
    expect(input_cantidad(@producto).value.to_i).to eq(0)

    # Removed from DB
    ps = Pedidos::Pedido.last.productos_solicitados.find_by(producto_id: @producto.id)
    expect(ps).to be_nil
  end

  scenario 'adding two different products updates the cart total' do
    login
    expect(page).to have_css('.producto-venta', wait: 10)

    within(product_card(@producto.nombre)) { find('a.mas').click }
    sleep 0.6
    within(product_card(@producto2.nombre)) { find('a.mas').click }
    sleep 0.6

    # Go to comprar (CC flow)
    carrito_btn = page.find('a, button', text: /ir al carrito/i, match: :first)
    carrito_btn.click
    expect(page).to have_current_path(%r{/pedidos/\d+/comprar}, wait: 5)

    # Total = 500 + 300 = 800
    expect(page).to have_content('800,00')
  end
end
