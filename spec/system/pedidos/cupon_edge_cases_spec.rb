# frozen_string_literal: true

require 'rails_helper'

# Covers cupon edge cases not addressed by the main cupon_pedido_flow_spec:
#   - Expired cupon → error message
#   - Already-used cupon → error message
#   - Case-insensitive code entry
#   - Cancelled cupon → error message
#   - Porcentaje cupon with limite_bonificacion cap
RSpec.describe 'Cupon edge cases', :js, type: :system do
  before do
    @tienda = create(:tienda,
                     nombre: 'Cupon Edge Store',
                     dominio: 'localhost',
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    @cliente = create(:cliente,
                      nombre: 'Cliente Cupon Edge',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: true,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta, nombre: 'Cuenta Cupon Edge', cliente: @cliente)

    @user = create(:usuario, :cliente,
                   login: 'cuponedgeuser',
                   password: 'password123',
                   password_confirmation: 'password123',
                   nombre: 'Cupon Edge User',
                   email: 'cuponedge@example.com',
                   cuenta: @cuenta,
                   tienda_cliente: @tienda,
                   visualizando_tienda: @tienda)

    @categoria = create(:categoria,
                        nombre: 'Viandas Edge',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria, nombre: 'Menu Dummy', tienda: @tienda, menu_diario: true)

    @cliente.categorias << @categoria

    @producto = create(:producto, nombre: 'Pollo Grillado', tienda: @tienda, categoria: @categoria)

    create(:precio, producto: @producto, importe: 1000.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def login
    visit root_path
    fill_in 'username', with: 'cuponedgeuser'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path(%r{/pedidos}, wait: 10)
  end

  def add_product_and_go_to_comprar
    expect(page).to have_css('.producto-venta', wait: 10)
    card = page.all('.producto-venta').find { |c| c.text.include?(@producto.nombre) }
    within(card) { find('a.mas').click }
    sleep 0.8
    carrito_btn = page.find('a, button', text: /ir al carrito/i, match: :first)
    carrito_btn.click
    expect(page).to have_current_path(%r{/pedidos/\d+/comprar}, wait: 5)
  end

  def apply_cupon(codigo)
    fill_in 'cupon_codigo_input', with: codigo
    find('#aplicar_cupon_btn').click
  end

  scenario 'expired cupon shows invalid/vencido error' do
    # Must use update_column to bypass after_save :asegurar_fecha_vencimiento
    # which resets fecha_vencimiento to 3 months from now if it's in the past
    cupon = create(:cupon, tienda: @tienda, codigo: 'VENCIDO1')
    cupon.update_column(:fecha_vencimiento, Date.current - 1.day)
    login
    add_product_and_go_to_comprar
    apply_cupon('VENCIDO1')

    expect(page).to have_content(/inválido|vencido|utilizado/i, wait: 5)
    expect(page).to have_css('#cupon_codigo_input')
    expect(page).not_to have_css('#quitar_cupon_btn')
  end

  scenario 'cancelled cupon shows invalid error' do
    create(:cupon, :cancelado, tienda: @tienda, codigo: 'CANCELAD1')
    login
    add_product_and_go_to_comprar
    apply_cupon('CANCELAD1')

    expect(page).to have_content(/inválido|vencido|utilizado/i, wait: 5)
    expect(page).not_to have_css('#quitar_cupon_btn')
  end

  scenario 'already-used cupon (linked to another pedido) shows invalid error' do
    cupon = create(:cupon, tienda: @tienda, codigo: 'USADO001')
    # Use a far-future fecha so otro_pedido doesn't conflict with the test user's current pedido
    otra_fecha = Date.current + 60.days
    otra_fecha += 1.day while otra_fecha.saturday? || otra_fecha.sunday?
    otro_pedido = build(:pedido, tienda: @tienda, cuenta: @cuenta, estado_id: 1,
                                 fecha: otra_fecha, autor: @user, usuario: @user)
    otro_pedido.asignar_cuenta_manual
    otro_pedido.cuenta = @cuenta
    otro_pedido.save(validate: false)
    create(:producto_solicitado, pedido: otro_pedido, producto: @producto, cantidad: 1, precio_unitario: 1000.0)
    otro_pedido.update_column(:cupon_id, cupon.id)
    expect(cupon.reload.usado?).to be(true)

    login
    add_product_and_go_to_comprar
    apply_cupon('USADO001')

    expect(page).to have_content(/inválido|vencido|utilizado/i, wait: 5)
    expect(page).not_to have_css('#quitar_cupon_btn')
  end

  scenario 'cupon code is accepted case-insensitively (lowercase input)' do
    create(:cupon, tienda: @tienda, tipo_descuento: 'importe', importe: 100, codigo: 'CASEUPPER')
    login
    add_product_and_go_to_comprar

    # Enter the code in lowercase
    apply_cupon('caseupper')

    # Should be accepted — total goes from $1000 to $900
    expect(page).to have_css('#quitar_cupon_btn', wait: 5)
    expect(page).to have_content('900,00', wait: 5)
  end

  scenario 'porcentaje cupon respects limite_bonificacion cap' do
    # 20% cupon with a $50 cap — on a $1000 order the discount should be $50, not $200
    create(:cupon, tienda: @tienda, tipo_descuento: 'porcentaje', porcentaje: 20,
                   limite_bonificacion: 50, codigo: 'PCT20CAP')
    login
    add_product_and_go_to_comprar

    apply_cupon('PCT20CAP')

    expect(page).to have_css('#quitar_cupon_btn', wait: 5)

    # Total should be $950 (1000 - 50 cap, not 1000 - 200)
    expect(page).to have_content('950,00', wait: 5)

    # The DB discount amount must not exceed the cap
    pedido = Pedidos::Pedido.last
    expect(pedido.importe_descuento_cupon.to_f).to eq(50.0)
  end
end
