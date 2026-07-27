# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ventas Mostrador - Async Footer Aggregates', :js, type: :system do
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
                     nombre: 'Tienda VM Async',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'vmasync@test.com',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    @cliente_cf = create(:cliente,
                         nombre: 'Consumidor Final',
                         tienda: @tienda,
                         dia_inicio_ciclo_facturacion: 1,
                         vencimiento_a: 30,
                         horarios_de_entrega: false,
                         usuario_puede_elegir_cuenta: false,
                         permitir_envios_a_domicilio: false,
                         cuenta_corriente: true,
                         listas_de_precio_privada: false)

    @cuenta_cf = @cliente_cf.cuentas.first || create(:cuenta,
                                                     nombre: 'Consumidor Final',
                                                     cliente: @cliente_cf)

    @admin = create(:usuario, :admin,
                    login: 'adminvmasync',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin VM Async',
                    email: 'adminvmasync@example.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    @categoria = create(:categoria,
                        nombre: 'Productos VM Async',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    @cliente_cf.categorias << @categoria unless @cliente_cf.categorias.include?(@categoria)

    @producto = create(:producto,
                       nombre: 'Empanada VM Async',
                       codigo: 'EMPVA1',
                       tienda: @tienda,
                       categoria: @categoria,
                       discontinued_at: nil)

    create(:precio, producto: @producto, importe: 200.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def create_vm_pedido(cantidad:)
    pedido = Pedidos::Pedido.new(
      autor: @admin, usuario: @admin, cuenta: @cuenta_cf,
      fecha: Date.current, estado_id: 1,
      tienda_id: @tienda.id, venta_mostrador: true
    )
    pedido.asignar_cuenta_manual
    pedido.cuenta = @cuenta_cf
    pedido.no_validar_fecha = true
    pedido.save!
    ps = Productos::ProductoSolicitado.new(
      pedido: pedido, producto: @producto,
      cantidad: cantidad, precio_unitario: 200.0
    )
    ps.save(validate: false)
    allow(pedido).to receive(:crear_comprobante)
    pedido.aceptar! if pedido.pendiente?
    pedido
  end

  scenario 'footer aggregates load asynchronously on ventas_mostrador index' do
    create_vm_pedido(cantidad: 2)
    create_vm_pedido(cantidad: 4)

    admin_login(@admin)

    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)

    # Table should render immediately with placeholder footers
    within('#pedidos-container') do
      expect(page).to have_css('table#pedidos', wait: 10)
      expect(page).to have_css('#footer-pedidos-count', wait: 10)

      # Wait for async load to populate values
      expect(page).to have_css('#footer-pedidos-count', text: '2', wait: 10)
      expect(page).to have_css('#footer-cantidad-total', text: '6', wait: 10)
    end
  end

  scenario 'footer aggregates reload after filter submission on ventas_mostrador' do
    create_vm_pedido(cantidad: 3)

    admin_login(@admin)

    visit ventas_mostrador_pedidos_path(show_filtro: true)
    expect(page).to have_content('Venta Mostrador', wait: 10)

    # Wait for initial async load
    expect(page).to have_css('#footer-pedidos-count', text: '1', wait: 10)
    expect(page).to have_css('#footer-cantidad-total', text: '3', wait: 10)

    # Submit filters
    click_button 'Buscar'

    # Values should reload
    expect(page).to have_css('#footer-pedidos-count', text: '1', wait: 10)
    expect(page).to have_css('#footer-cantidad-total', text: '3', wait: 10)
  end
end
