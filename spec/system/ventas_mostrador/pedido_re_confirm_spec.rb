# frozen_string_literal: true

require 'rails_helper'

# Regression test for production bug:
# Re-confirming a venta mostrador pedido that was originally confirmed with a
# descuento_venta_mostrador creates a discount NC against the factura. On
# re-edit + re-confirm, anular_factura generates a full-amount cancelation NC
# which, together with the existing discount NC, exceeds the factura total
# and fails the no_excede_total_factura validation on nc.confirmar(u).save!
#
# Fix: scale the cancelation NC renglones to only cover the remaining
# uncredited amount (total_factura - ya_creditado).
RSpec.describe 'VentasMostrador - Re-confirm Pedido', :js, type: :system do
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

    Comprobantes::Tipo.find_or_create_by(codigo: 4) do |tipo|
      tipo.desc = 'Recibo'
      tipo.clase = 'Cobros::Recibo'
      tipo.letra = 'X'
      tipo.debitan = false
    end

    @tienda = create(:tienda,
                     nombre: 'Tienda ReConfirm',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@reconfirm.com',
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
                    login: 'adminreconfirm',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin ReConfirm',
                    email: 'adminreconfirm@example.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    @categoria = create(:categoria,
                        nombre: 'Productos ReConfirm',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    @cliente_cf.categorias << @categoria unless @cliente_cf.categorias.include?(@categoria)

    @producto = create(:producto,
                       nombre: 'Milanesa RC',
                       codigo: 'MILRC01',
                       tienda: @tienda,
                       categoria: @categoria,
                       pesable: false,
                       discontinued_at: nil)

    create(:precio, producto: @producto, importe: 3000.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def login_and_visit_vm
    visit root_path
    fill_in 'username', with: 'adminreconfirm'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)
  end

  def add_product_and_wait
    fill_in 'codigo', with: 'MILRC01'
    find('#codigo').native.send_keys(:return)
    expect(page).to have_content('Milanesa RC', wait: 5)
    sleep 1
  end

  scenario 'can re-confirm after changing medio de pago (no discount case)' do
    login_and_visit_vm
    add_product_and_wait

    # Set medio de pago to efectivo $3000
    within('#medio-pago-selector') do
      find('.medio-pago-tipo').find("option[value='efectivo']").select_option
      fill_in class: 'medio-pago-importe', with: '3000'
    end

    # First confirm
    accept_confirm { click_button 'Confirmar e Imprimir (F10)' }
    expect(page).to have_content('confirmado correctamente', wait: 10)

    # Find the confirmed pedido and click edit
    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true, estado_id: 3).order(id: :desc).first
    expect(pedido).to be_present

    accept_confirm do
      find("a[href='#{edit_ventas_mostrador_pedido_path(pedido)}']", wait: 5).click
    end

    # Pedido is now back in pendiente state on the form
    expect(page).to have_content('Milanesa RC', wait: 10)

    # Change medio de pago to QR
    within('#medio-pago-selector') do
      find('.medio-pago-tipo').find("option[value='qr']").select_option
      fill_in class: 'medio-pago-importe', with: '3000'
    end

    # Re-confirm - should succeed without errors
    accept_confirm { click_button 'Confirmar e Imprimir (F10)' }
    expect(page).to have_content('confirmado correctamente', wait: 10)

    pedido.reload
    expect(pedido.estado_id).to eq(3)
    expect(pedido.comprobantes.where(type: 'Ventas::Facturacion::Factura').count).to eq(2)
  end

  # NOTE: the partial-discount-NC variant of this bug (production exception
  # "El total de notas de crédito ($3600.00) excede el total de la factura
  # ($3000.00)") is exercised as a model spec in
  # spec/models/pedidos/pedido_spec.rb under
  # "#anular_factura with partial discount NC already credited (Bug F)" — the
  # interaction with descuento_venta_mostrador + medio_pago change is too
  # JS-timing-sensitive to drive reliably through Capybara.
end
