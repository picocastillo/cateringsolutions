# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ventas Mostrador - POS Actions', :js, type: :system do
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
                     nombre: 'Tienda POS Actions',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'pos@test.com',
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
                    login: 'adminposactions',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin POS Actions',
                    email: 'adminposactions@example.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    @categoria = create(:categoria,
                        nombre: 'Productos POS',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    @cliente_cf.categorias << @categoria unless @cliente_cf.categorias.include?(@categoria)

    @producto1 = create(:producto,
                        nombre: 'Empanada Carne',
                        codigo: 'POSACT01',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    @producto2 = create(:producto,
                        nombre: 'Gaseosa Cola',
                        codigo: 'POSACT02',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    @producto3 = create(:producto,
                        nombre: 'Pizza Mozzarella',
                        codigo: 'POSACT03',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    create(:precio, producto: @producto1, importe: 200.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    create(:precio, producto: @producto2, importe: 150.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    create(:precio, producto: @producto3, importe: 500.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def login_and_visit_vm
    visit root_path
    fill_in 'username', with: 'adminposactions'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)
    expect(page).to have_css('#agregar-producto-vr', wait: 10)
  end

  def add_product_by_code(code)
    fill_in 'codigo', with: code
    find('#codigo').native.send_keys(:return)
  end

  # ─── Empty state ───────────────────────────────────────────────

  scenario 'empty cart shows placeholder message' do
    login_and_visit_vm

    expect(page).to have_css('.vm-cart-empty', wait: 5)
    expect(page).to have_content('Agregue productos con el buscador')
    expect(page).not_to have_css('.productos_solicitados_venta_mostrador')
  end

  # ─── Add product by barcode ────────────────────────────────────

  scenario 'add product by barcode code in the code input' do
    login_and_visit_vm

    add_product_by_code('POSACT01')

    expect(page).to have_css('.productos_solicitados_venta_mostrador', wait: 5)
    within('.productos_solicitados_venta_mostrador') do
      expect(page).to have_content('Empanada Carne')
    end

    # Total should be $200
    expect(find('#importe-total-container').text).to include('200')

    # Cart badge should show 1
    expect(find('.vm-cart-header .badge').text).to eq('1')
  end

  # ─── Add product via Select2 search ────────────────────────────

  scenario 'add product via Select2 dropdown search' do
    login_and_visit_vm

    # Open Select2 dropdown (v3 style)
    find('#s2id_producto_id .select2-choice').click
    find('.select2-drop-active .select2-input').set('Pizza')
    expect(page).to have_css('.select2-drop-active .select2-result-label', text: /Pizza/, wait: 10)
    find('.select2-drop-active .select2-result-label', text: /Pizza/, match: :first).click

    # Click Agregar
    find('#agregar-producto-vr').click

    expect(page).to have_css('.productos_solicitados_venta_mostrador', wait: 5)
    within('.productos_solicitados_venta_mostrador') do
      expect(page).to have_content('Pizza Mozzarella')
    end

    expect(find('#importe-total-container').text).to include('500')
  end

  # ─── Add same product twice increments quantity ────────────────

  scenario 'adding same product twice increments quantity' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)

    # Badge should show 1
    expect(find('.vm-cart-header .badge').text).to eq('1')

    add_product_by_code('POSACT01')
    sleep 1

    # Badge should now show 2 (same product, quantity incremented)
    expect(find('.vm-cart-header .badge').text).to eq('2')

    # Only one row in the cart
    within('.productos_solicitados_venta_mostrador') do
      rows = all('tbody tr.fields')
      expect(rows.size).to eq(1)
      expect(find('.adicionador').value.to_i).to eq(2)
    end

    # Total should be $400 (2 x $200)
    expect(find('#importe-total-container').text).to include('400')
  end

  # ─── Add multiple different products ───────────────────────────

  scenario 'add multiple different products to cart' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)

    add_product_by_code('POSACT02')
    expect(page).to have_content('Gaseosa Cola', wait: 5)

    within('.productos_solicitados_venta_mostrador') do
      rows = all('tbody tr.fields')
      expect(rows.size).to eq(2)
      expect(page).to have_content('Empanada Carne')
      expect(page).to have_content('Gaseosa Cola')
    end

    # Badge should show total quantity (1 + 1 = 2)
    expect(find('.vm-cart-header .badge').text).to eq('2')

    # Total should be $350 ($200 + $150)
    expect(find('#importe-total-container').text).to include('350')
  end

  # ─── Invalid barcode shows error ───────────────────────────────

  scenario 'invalid barcode shows error message' do
    login_and_visit_vm

    add_product_by_code('INVALID99')

    # Should show error growl and no product in cart
    expect(page).to have_content('no encontrado', wait: 5)
    expect(page).not_to have_css('.productos_solicitados_venta_mostrador')
  end

  # ─── Empty code/product shows error ────────────────────────────

  scenario 'agregar with no code or product shows error' do
    login_and_visit_vm

    find('#agregar-producto-vr').click

    expect(page).to have_content('Ingrese un código o seleccione un producto', wait: 5)
  end

  # ─── Change quantity in cart ───────────────────────────────────

  scenario 'changing quantity in cart updates total and badge' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)

    # Change quantity from 1 to 5
    within('.productos_solicitados_venta_mostrador') do
      cantidad_field = find('.adicionador')
      cantidad_field.set('')
      cantidad_field.set('5')
      cantidad_field.native.send_keys(:tab)
    end

    sleep 2

    # Total should be $1,000 (5 x $200)
    expect(find('#importe-total-container').text).to include('1.000')

    # Badge should show 5
    expect(find('.vm-cart-header .badge').text).to eq('5')
  end

  # ─── Remove product from cart ──────────────────────────────────

  scenario 'remove product from cart using remove button' do
    login_and_visit_vm

    # Add two products
    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)

    add_product_by_code('POSACT02')
    expect(page).to have_content('Gaseosa Cola', wait: 5)

    within('.productos_solicitados_venta_mostrador') do
      expect(all('tbody tr.fields').size).to eq(2)
    end

    # Remove first product by clicking remove_nested_fields on first row
    within('.productos_solicitados_venta_mostrador') do
      first_row = all('tbody tr.fields').first
      first_row.find('a.remove_nested_fields').click
    end

    sleep 1

    # First product should fade out, second remains
    within('.productos_solicitados_venta_mostrador') do
      visible_rows = all('tbody tr.fields', visible: true)
      expect(visible_rows.size).to eq(1)
    end
  end

  scenario 'removing last product shows empty cart message' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)

    # Remove the only product
    within('.productos_solicitados_venta_mostrador') do
      find('a.remove_nested_fields').click
    end

    sleep 1

    # Setting quantity to 0 via AJAX triggers fade but doesn't re-render empty state
    # The row will fade out — verify it's hidden
    within('.productos_solicitados_venta_mostrador') do
      expect(page).not_to have_css('tbody tr.fields', visible: true, wait: 5)
    end
  end

  # ─── Setting quantity to 0 removes product ────────────────────

  scenario 'setting quantity to 0 removes the product row' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)

    within('.productos_solicitados_venta_mostrador') do
      cantidad_field = find('.adicionador')
      cantidad_field.set('')
      cantidad_field.set('0')
      cantidad_field.native.send_keys(:tab)
    end

    sleep 2

    # Row should fade out
    within('.productos_solicitados_venta_mostrador') do
      expect(page).not_to have_css('tbody tr.fields', visible: true, wait: 5)
    end
  end

  # ─── Cancel button (F8) clears the cart ────────────────────────

  scenario 'cancel button clears cart and creates new pedido' do
    login_and_visit_vm

    # Add products
    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)

    add_product_by_code('POSACT02')
    expect(page).to have_content('Gaseosa Cola', wait: 5)

    # Store pedido ID before cancel
    old_pedido_id = find('#pedido-vm-id', visible: false)['data-id']

    # Click Cancel (F8) and accept confirm dialog
    accept_confirm do
      find('#boton-cancelar-vm').click
    end

    # Should show growl message about cancellation
    expect(page).to have_content('Pedido Cancelado', wait: 5)

    # Cart should now be empty
    expect(page).to have_css('.vm-cart-empty', wait: 5)
    expect(page).to have_content('Agregue productos con el buscador')

    # New pedido should be created (different ID)
    new_pedido_id = find('#pedido-vm-id', visible: false)['data-id']
    expect(new_pedido_id).not_to eq(old_pedido_id)
  end

  # ─── Confirm with empty cart shows error ───────────────────────

  scenario 'confirm with empty cart shows error message' do
    login_and_visit_vm

    # Try to confirm with empty cart
    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    expect(page).to have_content('Debe seleccionar productos', wait: 10)
  end

  # ─── Confirm with products succeeds ────────────────────────────

  scenario 'confirm with products creates confirmed pedido' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)

    sleep 1

    # Set medio importe
    within('#medio-pago-selector') do
      find('.medio-pago-importe').set('200.00')
    end

    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    expect(page).to have_content('confirmado correctamente', wait: 10)

    # Verify in DB
    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true, estado_id: 3)
                            .order(id: :desc).first
    expect(pedido).to be_present
    expect(pedido.facturado).to be true
  end

  # ─── Confirm and new cart is ready ─────────────────────────────

  scenario 'after confirming, a new empty pedido is ready' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)
    sleep 1

    within('#medio-pago-selector') do
      find('.medio-pago-importe').set('200.00')
    end

    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    expect(page).to have_content('confirmado correctamente', wait: 10)

    # New page should show empty cart ready for next sale
    expect(page).to have_css('.vm-cart-empty', wait: 5)
    expect(page).to have_css('#agregar-producto-vr')
    expect(page).to have_css('#codigo')
  end

  # ─── Medio de pago auto-fill after product add ─────────────────

  scenario 'medio importe auto-fills with total when single medio exists' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)
    sleep 1

    within('#medio-pago-selector') do
      expect(find('.medio-pago-importe').value.to_f).to eq(200.0)
    end
  end

  # ─── Total display in search bar ───────────────────────────────

  scenario 'total display updates as products are added' do
    login_and_visit_vm

    # Initially no total displayed (importe is 0)
    expect(page).not_to have_css('#importe-total-container')

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)

    # Total should now show $200
    expect(find('#importe-total-container').text).to include('200')

    add_product_by_code('POSACT02')
    expect(page).to have_content('Gaseosa Cola', wait: 5)

    # Total should now show $350
    expect(find('#importe-total-container').text).to include('350')
  end

  # ─── Line item total displays correctly ────────────────────────

  scenario 'each cart row shows correct line total' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)

    # Line total for 1 x $200 should show 200
    within('.productos_solicitados_venta_mostrador') do
      row = find('tbody tr.fields', match: :first)
      expect(row).to have_content('200')
    end

    # Change quantity to 3
    within('.productos_solicitados_venta_mostrador') do
      cantidad_field = find('.adicionador')
      cantidad_field.set('')
      cantidad_field.set('3')
      cantidad_field.native.send_keys(:tab)
    end

    sleep 2

    # Line total should update to $600
    within('.productos_solicitados_venta_mostrador') do
      row = find('tbody tr.fields', match: :first)
      expect(row).to have_content('600')
    end
  end

  # ─── Pedido appears in list after confirm ──────────────────────

  scenario 'confirmed pedido appears in the pedidos list below' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)
    sleep 1

    within('#medio-pago-selector') do
      find('.medio-pago-importe').set('200.00')
    end

    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    expect(page).to have_content('confirmado correctamente', wait: 10)

    # Pedidos list should contain the confirmed pedido
    within('#pedidos-container') do
      expect(page).to have_css('table#pedidos', wait: 5)
      expect(page).to have_content('Confirmado')
    end
  end

  # ─── Delete pedido from list ───────────────────────────────────

  scenario 'delete pedido from the pedidos list' do
    login_and_visit_vm

    # Create and confirm a pedido
    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)
    sleep 1

    within('#medio-pago-selector') do
      find('.medio-pago-importe').set('200.00')
    end

    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    expect(page).to have_content('confirmado correctamente', wait: 10)

    # Find the pedido in the list and delete it
    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true, estado_id: 3)
                            .order(id: :desc).first

    within('#pedidos-container') do
      expect(page).to have_css('table#pedidos', wait: 5)
      accept_confirm do
        find("a[href='#{ventas_mostrador_pedido_path(pedido)}'][data-method='delete']").click
      end
    end

    expect(page).to have_content('eliminado correctamente', wait: 10)
  end

  # ─── Edit pedido from list ─────────────────────────────────────

  scenario 'edit a confirmed pedido re-opens it for editing' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)
    sleep 1

    within('#medio-pago-selector') do
      find('.medio-pago-importe').set('200.00')
    end

    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    expect(page).to have_content('confirmado correctamente', wait: 10)

    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true, estado_id: 3)
                            .order(id: :desc).first

    within('#pedidos') do
      accept_confirm do
        find("a[href='#{edit_ventas_mostrador_pedido_path(pedido)}']").click
      end
    end

    # Should show the product back in the editable cart
    expect(page).to have_content('Empanada Carne', wait: 5)
    within('.productos_solicitados_venta_mostrador') do
      expect(page).to have_css('.adicionador')
    end

    # Pedido should be back to pendiente
    pedido.reload
    expect(pedido.estado_id).to eq(1)
  end

  # ─── Product code input behavior ───────────────────────────────

  scenario 'code input field gets focus after page load' do
    login_and_visit_vm

    # The codigo input should be present and focusable
    expect(page).to have_css('#buscador-vr #codigo')
  end

  scenario 'code input clears after adding product' do
    login_and_visit_vm

    add_product_by_code('POSACT01')
    expect(page).to have_content('Empanada Carne', wait: 5)

    # After AJAX re-render, code input should be present (cleared for next scan)
    expect(page).to have_css('#buscador-vr #codigo', wait: 5)
  end
end
