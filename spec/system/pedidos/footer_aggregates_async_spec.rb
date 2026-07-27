# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pedidos Index - Async Footer Aggregates', :js, type: :system do
  before do
    @tienda = create(:tienda,
                     nombre: 'Tienda Async Test',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'async@test.com',
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    @cliente = create(:cliente,
                      nombre: 'Cliente Async',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      cuenta_corriente: true,
                      listas_de_precio_privada: false)

    @cuenta = @cliente.cuentas.first || create(:cuenta, nombre: 'Cuenta Async', cliente: @cliente)

    @admin = create(:usuario, :admin,
                    login: 'adminasync',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin Async',
                    email: 'adminasync@example.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    @categoria = create(:categoria,
                        nombre: 'Cat Async',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    @cliente.categorias << @categoria unless @cliente.categorias.include?(@categoria)

    @producto = create(:producto,
                       nombre: 'Producto Async',
                       codigo: 'PASYNC1',
                       tienda: @tienda,
                       categoria: @categoria,
                       discontinued_at: nil)

    create(:precio, producto: @producto, importe: 150.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def create_pedido_with_productos(cantidad:, precio: 150.0)
    pedido = Pedidos::Pedido.new(
      autor: @admin, usuario: @admin, cuenta: @cuenta,
      fecha: Date.current, estado_id: 1,
      tienda_id: @tienda.id
    )
    pedido.asignar_cuenta_manual
    pedido.cuenta = @cuenta
    pedido.no_validar_fecha = true
    pedido.save!
    ps = Productos::ProductoSolicitado.new(
      pedido: pedido, producto: @producto,
      cantidad: cantidad, precio_unitario: precio
    )
    ps.save(validate: false)
    allow(pedido).to receive(:crear_comprobante)
    pedido.aceptar! if pedido.pendiente?
    pedido
  end

  scenario 'footer aggregates load asynchronously on pedidos index' do
    create_pedido_with_productos(cantidad: 3)
    create_pedido_with_productos(cantidad: 5)

    admin_login(@admin)

    visit pedidos_path
    expect(page).to have_css('table#pedidos', wait: 10)

    # Wait for async load to populate the values
    expect(page).to have_css('#footer-pedidos-count', text: '2', wait: 15)
    expect(page).to have_css('#footer-cantidad-total', text: '8', wait: 10)
    expect(page).to have_css('#footer-importe-total', wait: 10)
    expect(find('#footer-importe-total').text).to match(/1.*200/)
  end

  scenario 'footer aggregates reload after filter form submission' do
    create_pedido_with_productos(cantidad: 3)
    create_pedido_with_productos(cantidad: 5)

    admin_login(@admin)

    visit pedidos_path(show_filtro: true)
    expect(page).to have_css('table#pedidos', wait: 10)

    # Wait for initial async load
    expect(page).to have_css('#footer-pedidos-count', text: '2', wait: 10)

    # Submit the filter form (with existing filters, no change — should still reload)
    click_button 'Buscar'

    # Wait for AJAX response and the new async footer load
    expect(page).to have_css('#footer-pedidos-count', text: '2', wait: 10)
    expect(page).to have_css('#footer-cantidad-total', text: '8', wait: 10)
  end

  scenario 'footer aggregates update when date filter narrows results' do
    # Pedido for today
    create_pedido_with_productos(cantidad: 3)

    # Pedido for yesterday — create and backdate
    old_pedido = create_pedido_with_productos(cantidad: 7)
    old_pedido.update_column(:fecha, Date.yesterday)

    admin_login(@admin)

    # Visit with filter open, fecha_desde = today (should show only 1 pedido)
    visit pedidos_path(show_filtro: true, q: { fecha_desde: Date.current.to_s })
    expect(page).to have_css('table#pedidos', wait: 10)

    expect(page).to have_css('#footer-pedidos-count', text: '1', wait: 10)
    expect(page).to have_css('#footer-cantidad-total', text: '3', wait: 10)
  end
end
