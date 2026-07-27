# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ventas Mostrador - Descuento Automático', :js, type: :system do
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
                     nombre: 'Tienda Desc Auto',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@descauto.com',
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
                    login: 'admindescauto',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin Desc Auto',
                    email: 'admindescauto@example.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    @categoria = create(:categoria,
                        nombre: 'Productos Desc Auto',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    @cliente_cf.categorias << @categoria unless @cliente_cf.categorias.include?(@categoria)

    @producto = create(:producto,
                       nombre: 'Milanesa',
                       codigo: 'MILDESC01',
                       tienda: @tienda,
                       categoria: @categoria,
                       pesable: false,
                       discontinued_at: nil)

    create(:precio, producto: @producto, importe: 500.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def login_and_visit_vm
    visit root_path
    fill_in 'username', with: 'admindescauto'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)
  end

  def add_product_and_wait
    fill_in 'codigo', with: 'MILDESC01'
    find('#codigo').native.send_keys(:return)
    expect(page).to have_content('Milanesa', wait: 5)
    sleep 1
  end

  scenario 'discount is automatically applied on confirm with matching efectivo rule' do
    # Create discount rule: $200 off for efectivo, minimum $400
    create(:descuento_venta_mostrador, tienda: @tienda,
                                       nombre: 'Efectivo $200 off',
                                       tipo_descuento: 'importe',
                                       importe: 200,
                                       medio_pago_tipo: 'efectivo',
                                       importe_minimo: 400)

    login_and_visit_vm
    add_product_and_wait # 1 x $500

    # Default medio de pago is efectivo
    within('#medio-pago-selector') do
      expect(find('.medio-pago-importe').value.to_f).to eq(500.0)
    end

    # Confirm the sale
    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    expect(page).to have_content('confirmado correctamente', wait: 10)
    expect(page).to have_content('Efectivo $200 off')

    # Verify DB: discount was applied (query confirmed pedido, not the new blank one)
    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true, estado_id: 3).order(id: :desc).first
    expect(pedido).to be_present
    expect(pedido.descuento_venta_mostrador).to be_present
    expect(pedido.descuento_venta_mostrador.nombre).to eq('Efectivo $200 off')
    expect(pedido.tiene_descuento_vm?).to be true

    # Items have distributed discount
    ps = pedido.productos_solicitados.first
    expect(ps.precio_con_descuento.to_f).to eq(300.0) # 500 - 200
  end

  scenario 'no discount applied when below minimum amount' do
    # Discount requires min $1000
    create(:descuento_venta_mostrador, tienda: @tienda,
                                       nombre: 'Efectivo big',
                                       tipo_descuento: 'importe',
                                       importe: 500,
                                       medio_pago_tipo: 'efectivo',
                                       importe_minimo: 1000)

    login_and_visit_vm
    add_product_and_wait # 1 x $500 < $1000 minimum

    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    expect(page).to have_content('confirmado correctamente', wait: 10)

    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true).order(id: :desc).first
    expect(pedido.descuento_venta_mostrador).to be_nil
    expect(pedido.tiene_descuento_vm?).to be false
  end

  scenario 'no discount applied when medio de pago does not match' do
    # Discount is for QR only
    create(:descuento_venta_mostrador, :qr, tienda: @tienda,
                                            nombre: 'QR only',
                                            importe: 100,
                                            importe_minimo: 0)

    login_and_visit_vm
    add_product_and_wait # Default medio is efectivo, discount is for QR

    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    expect(page).to have_content('confirmado correctamente', wait: 10)

    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true).order(id: :desc).first
    expect(pedido.descuento_venta_mostrador).to be_nil
  end

  scenario 'best discount is selected when multiple rules match' do
    # Two matching discounts for efectivo
    create(:descuento_venta_mostrador, tienda: @tienda,
                                       nombre: 'Small $50',
                                       tipo_descuento: 'importe',
                                       importe: 50,
                                       medio_pago_tipo: 'efectivo',
                                       importe_minimo: 0)
    create(:descuento_venta_mostrador, tienda: @tienda,
                                       nombre: 'Big $150',
                                       tipo_descuento: 'importe',
                                       importe: 150,
                                       medio_pago_tipo: 'efectivo',
                                       importe_minimo: 0)

    login_and_visit_vm
    add_product_and_wait # 1 x $500

    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    expect(page).to have_content('confirmado correctamente', wait: 10)

    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true, estado_id: 3).order(id: :desc).first
    expect(pedido.descuento_venta_mostrador.nombre).to eq('Big $150')
    expect(pedido.productos_solicitados.first.precio_con_descuento.to_f).to eq(350.0) # 500 - 150
  end

  scenario 'inactive discount is not applied' do
    create(:descuento_venta_mostrador, :inactivo, tienda: @tienda,
                                                  nombre: 'Inactive discount',
                                                  importe: 200,
                                                  medio_pago_tipo: 'efectivo',
                                                  importe_minimo: 0)

    login_and_visit_vm
    add_product_and_wait

    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    expect(page).to have_content('confirmado correctamente', wait: 10)

    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true).order(id: :desc).first
    expect(pedido.descuento_venta_mostrador).to be_nil
  end

  scenario 'medios de pago total matches discounted pedido total (no mismatch error)' do
    # Percentage discount: 10% off for efectivo, no minimum
    create(:descuento_venta_mostrador, tienda: @tienda,
                                       nombre: 'Efectivo 10%',
                                       tipo_descuento: 'porcentaje',
                                       porcentaje: 10,
                                       limite_bonificacion: 99_999,
                                       medio_pago_tipo: 'efectivo',
                                       importe_minimo: 0)

    # Create a second product to simulate multiple items (closer to real-world)
    producto2 = create(:producto,
                       nombre: 'Empanada',
                       codigo: 'EMPDESC01',
                       tienda: @tienda,
                       categoria: @categoria,
                       pesable: false,
                       discontinued_at: nil)
    create(:precio, producto: producto2, importe: 300.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)

    login_and_visit_vm

    # Add first product ($500)
    add_product_and_wait

    # Add second product ($300)
    fill_in 'codigo', with: 'EMPDESC01'
    find('#codigo').native.send_keys(:return)
    expect(page).to have_content('Empanada', wait: 5)
    sleep 1

    # Medio de pago should show the full pre-discount total ($800)
    within('#medio-pago-selector') do
      expect(find('.medio-pago-importe').value.to_f).to eq(800.0)
    end

    # Confirm — discount should be applied WITHOUT "no coincide" error
    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    # Must NOT see the "no coincide" error
    expect(page).not_to have_content('no coincide con el total del pedido', wait: 3)
    expect(page).to have_content('confirmado correctamente', wait: 10)
    expect(page).to have_content('Efectivo 10%')

    # Verify DB
    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true, estado_id: 3).order(id: :desc).first
    expect(pedido).to be_present
    expect(pedido.descuento_venta_mostrador.nombre).to eq('Efectivo 10%')

    # 10% of $800 = $80 discount -> total = $720
    expect(pedido.importe_total.to_f).to eq(720.0)

    # Medio de pago was adjusted to match the discounted total
    mp = pedido.medios_pago.first
    expect(mp.importe.to_f).to eq(720.0)
  end

  scenario 'discount preview shows in POS total before confirming' do
    create(:descuento_venta_mostrador, tienda: @tienda,
                                       nombre: 'Efectivo $200 off',
                                       tipo_descuento: 'importe',
                                       importe: 200,
                                       medio_pago_tipo: 'efectivo',
                                       importe_minimo: 400)

    login_and_visit_vm
    add_product_and_wait # 1 x $500 (above $400 minimum)

    # The discount preview should appear in the total badge BEFORE confirming
    within('#importe-total-container') do
      expect(page).to have_css('.vm-total-descuento', wait: 5)
      expect(page).to have_content('Efectivo $200 off')
      expect(page).to have_content('200') # discount amount
      expect(find('.vm-total-final').text).to include('300') # 500 - 200
    end
  end
end
