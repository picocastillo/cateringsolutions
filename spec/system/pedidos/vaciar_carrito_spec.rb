# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Vaciar Carrito', :js, type: :system do
  before do
    Comprobantes::Tipo.find_or_create_by(codigo: 1) do |tipo|
      tipo.desc = 'Factura'
      tipo.clase = 'Ventas::Facturacion::Factura'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    @tienda = create(:tienda,
                     nombre: 'Tienda Vaciar Carrito',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@vaciar.com',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    @cliente = create(:cliente,
                      nombre: 'Cliente Vaciar',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: true,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta,
                     nombre: 'Cuenta Vaciar',
                     cliente: @cliente)

    @cliente_user = create(:usuario, :cliente,
                           login: 'clientevaciar',
                           password: 'password123',
                           password_confirmation: 'password123',
                           nombre: 'Cliente Vaciar User',
                           email: 'clientevaciar@example.com',
                           cuenta: @cuenta,
                           tienda_cliente: @tienda,
                           visualizando_tienda: @tienda)

    @categoria = create(:categoria,
                        nombre: 'Comidas',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    @cliente.categorias << @categoria unless @cliente.categorias.include?(@categoria)

    @producto = create(:producto,
                       nombre: 'Empanada de Carne',
                       codigo: 'EMP001',
                       tienda: @tienda,
                       categoria: @categoria,
                       discontinued_at: nil)

    create(:precio, producto: @producto, importe: 100.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def fecha_pedido_valida(offset = 0)
    fecha = @cuenta.proximo_dia_pedido + offset.days
    fecha += 1.day while fecha.saturday? || fecha.sunday?
    fecha
  end

  def crear_pedido_con_producto(fecha: fecha_pedido_valida, grupo: nil)
    pedido = build(:pedido,
                   tienda: @tienda,
                   cuenta: @cuenta,
                   estado_id: 1,
                   fecha: fecha,
                   autor: @cliente_user,
                   usuario: @cliente_user,
                   pedido_multiple: grupo)
    pedido.asignar_cuenta_manual
    pedido.cuenta = @cuenta
    pedido.save!
    create(:producto_solicitado, pedido: pedido, producto: @producto, cantidad: 1, precio_unitario: 100.0)
    pedido
  end

  def expect_grupo_vaciado(grupo, pedido_actual, pedidos_eliminados)
    expect(page).not_to have_css('.gbs-wrap', wait: 10)
    expect(page).to have_css('#listado-de-productos', wait: 10)

    expect(Pedidos::PedidoMultiple.exists?(grupo.id)).to be(false)
    expect(pedido_actual.reload.pedido_multiple_id).to be_nil
    expect(pedido_actual.productos_solicitados.reload).to be_empty
    pedidos_eliminados.each do |pedido|
      expect(Pedidos::Pedido.exists?(pedido.id)).to be(false)
    end
  end

  def datepicker_date_ms(fecha)
    fecha.to_time(:utc).to_i * 1000
  end

  def abrir_datepicker
    find('#pedido_fecha').click
    expect(page).to have_css('.datepicker-days td.day[data-date]', wait: 5)
  end

  scenario 'cliente adds product then empties cart without errors' do
    visit root_path
    fill_in 'username', with: 'clientevaciar'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'

    expect(page).to have_current_path(%r{/pedidos}, wait: 5)
    expect(page).to have_css('.producto-venta', wait: 10)

    # Add product to cart
    producto_card = page.find('.producto-venta', text: @producto.nombre)
    within(producto_card) do
      find('a.mas').click
    end

    # Wait for cart to update via AJAX
    sleep 2

    # Verify product was added (cart badge shows total)
    expect(page).to have_css('#total-pedido-pendiente', wait: 5)
    expect(page).to have_css('#multi-fecha-hint', visible: :visible, wait: 5)

    # Click "Vaciar Carrito" and accept confirmation
    accept_confirm('Desea vaciar el Carrito?') do
      page.execute_script("document.querySelector('.vaciar-pedido').click()")
    end

    # Wait for AJAX to complete - the key assertion: no JS errors and
    # the productos_en_venta partial renders with @categorias_disponibles
    sleep 3

    # Verify the category selector still renders (this is what was crashing:
    # undefined method 'map' for nil when @categorias_disponibles was nil)
    expect(page).to have_css('#categoria-selector', visible: :all, wait: 5)

    # Verify products are still shown after emptying cart
    expect(page).to have_css('#listado-de-productos', wait: 5)
    expect(page).not_to have_css('#multi-fecha-hint', visible: :visible, wait: 5)
    expect(page).to have_css('.producto-venta', text: @producto.nombre, wait: 10)
  end

  scenario 'form Vaciar button empties every pedido in the group' do
    grupo = Pedidos::PedidoMultiple.create!(usuario: @cliente_user)
    pedido_actual = crear_pedido_con_producto(grupo: grupo)
    pedido_otro_dia = crear_pedido_con_producto(fecha: fecha_pedido_valida(1), grupo: grupo)
    pedido_tercer_dia = crear_pedido_con_producto(fecha: fecha_pedido_valida(2), grupo: grupo)

    cliente_login(@cliente_user)
    visit edit_pedido_path(pedido_actual)

    expect(page).to have_css('.gbs-wrap', wait: 5)
    expect(page).to have_css('.gbs-tab', count: 3)
    abrir_datepicker
    expect(page).to have_css(".datepicker-days td.day.pedido-group-date[data-date='#{datepicker_date_ms(pedido_actual.fecha)}']")
    find('#pedido_fecha').send_keys(:escape)

    accept_confirm('Desea vaciar el Carrito?') do
      page.execute_script("document.querySelector('#boton-compra .vaciar-pedido').click()")
    end

    expect_grupo_vaciado(grupo, pedido_actual, [pedido_otro_dia, pedido_tercer_dia])
    abrir_datepicker
    expect(page).not_to have_css('.datepicker-days td.day.pedido-group-date', wait: 5)
  end

  scenario 'cart dropdown Vaciar Carrito link empties every pedido in the group' do
    grupo = Pedidos::PedidoMultiple.create!(usuario: @cliente_user)
    pedido_actual = crear_pedido_con_producto(grupo: grupo)
    pedido_otro_dia = crear_pedido_con_producto(fecha: fecha_pedido_valida(1), grupo: grupo)
    pedido_tercer_dia = crear_pedido_con_producto(fecha: fecha_pedido_valida(2), grupo: grupo)

    cliente_login(@cliente_user)
    visit edit_pedido_path(pedido_actual)

    expect(page).to have_css('.gbs-wrap', wait: 5)
    expect(page).to have_css('#pedido-en-curso .vaciar-pedido', visible: :all, wait: 5)

    accept_confirm('Desea vaciar el Carrito?') do
      page.execute_script("document.querySelector('#pedido-en-curso .vaciar-pedido').click()")
    end

    expect_grupo_vaciado(grupo, pedido_actual, [pedido_otro_dia, pedido_tercer_dia])
  end
end
