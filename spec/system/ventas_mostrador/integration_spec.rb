# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ventas Mostrador - Integration', :js, type: :system do
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
                     nombre: 'Tienda Integration',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@integration.com',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false,
                     productos_pesables: true)

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
                    login: 'adminintegration',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin Integration',
                    email: 'adminintegration@example.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    @categoria = create(:categoria,
                        nombre: 'Productos Integration',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    @cliente_cf.categorias << @categoria unless @cliente_cf.categorias.include?(@categoria)

    @producto_normal = create(:producto,
                              nombre: 'Empanada Carne',
                              codigo: 'EMPINT01',
                              tienda: @tienda,
                              categoria: @categoria,
                              pesable: false,
                              discontinued_at: nil)

    @producto_pesable = create(:producto,
                               nombre: 'Queso Cremoso',
                               codigo: 'QUEINT01',
                               tienda: @tienda,
                               categoria: @categoria,
                               pesable: true,
                               discontinued_at: nil)

    create(:precio, producto: @producto_normal, importe: 200.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    create(:precio, producto: @producto_pesable, importe: 800.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def login_and_visit_vm
    visit root_path
    fill_in 'username', with: 'adminintegration'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)
  end

  scenario 'full flow: mixed cart, edit quantities, split payment across two medios' do
    login_and_visit_vm

    # --- Step 1: Add regular product ---
    fill_in 'codigo', with: 'EMPINT01'
    find('#codigo').native.send_keys(:return)
    expect(page).to have_content('Empanada Carne', wait: 5)

    # --- Step 2: Add pesable product via peso modal ---
    fill_in 'codigo', with: 'QUEINT01'
    find('#codigo').native.send_keys(:return)
    expect(page).to have_css('#peso-modal', visible: true, wait: 5)
    fill_in 'peso-modal-input', with: '1.5'
    click_button 'peso-modal-confirmar'
    expect(page).not_to have_css('#peso-modal.show', wait: 5)

    # Both products should be in cart
    within('.productos_solicitados_venta_mostrador') do
      expect(page).to have_content('Empanada Carne')
      expect(page).to have_content('Queso Cremoso')
    end

    # Wait for auto-fill
    sleep 1

    # Initial total: 1 x $200 + 1.5kg x $800 = $200 + $1,200 = $1,400
    total_text = find('#importe-total-container').text
    expect(total_text).to include('1.400')

    # --- Step 3: Edit quantity of regular product (1 -> 3) ---
    within('.productos_solicitados_venta_mostrador') do
      cantidad_field = find('.adicionador')
      cantidad_field.set('')
      cantidad_field.set('3')
      cantidad_field.native.send_keys(:tab)
    end

    # Wait for AJAX update
    sleep 2

    # New total: 3 x $200 + 1.5kg x $800 = $600 + $1,200 = $1,800
    total_text = find('#importe-total-container').text
    expect(total_text).to include('1.800')

    # --- Step 4: Edit peso of pesable product (1.5 -> 2.0 kg) ---
    within('.productos_solicitados_venta_mostrador') do
      peso_field = find('.peso-input')
      peso_field.set('')
      peso_field.set('2.0')
      peso_field.native.send_keys(:tab)
    end

    # Wait for AJAX update
    sleep 2

    # New total: 3 x $200 + 2.0kg x $800 = $600 + $1,600 = $2,200
    total_text = find('#importe-total-container').text
    expect(total_text).to include('2.200')

    # --- Step 5: Split payment across two medios de pago ---
    within('#medio-pago-selector') do
      # Add second medio de pago
      find('a.add_nested_fields').click
      expect(page).to have_css('#medios-pago-rows .fields', count: 2)

      rows = all('#medios-pago-rows .fields')

      # First: Efectivo $1,200
      rows[0].find('.medio-pago-importe').set('1200.00')

      # Second: Débito $1,000
      rows[1].find('.medio-pago-tipo').select('Débito')
      rows[1].find('.medio-pago-importe').set('1000.00')

      # Verify values
      expect(rows[0].find('.medio-pago-tipo').value).to eq('efectivo')
      expect(rows[0].find('.medio-pago-importe').value).to eq('1200.00')
      expect(rows[1].find('.medio-pago-tipo').value).to eq('debito')
      expect(rows[1].find('.medio-pago-importe').value).to eq('1000.00')
    end

    # --- Step 6: Verify DB state ---
    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true)
                            .order(id: :desc).first
    expect(pedido).to be_present
    expect(pedido.importe_total.to_f).to eq(2200.0)

    # Verify productos solicitados
    ps_normal = pedido.productos_solicitados.find { |ps| ps.producto_id == @producto_normal.id }
    ps_pesable = pedido.productos_solicitados.find { |ps| ps.producto_id == @producto_pesable.id }

    expect(ps_normal.cantidad).to eq(3)
    expect(ps_pesable.cantidad).to eq(1)
    expect(ps_pesable.peso.to_f).to eq(2.0)

    # Verify individual totals
    expect(ps_normal.importe_total.to_f).to eq(600.0) # 3 x $200
    expect(ps_pesable.importe_total.to_f).to eq(1600.0) # 2.0kg x $800
  end

  scenario 'confirm button navigates on single click' do
    login_and_visit_vm

    # Add a product
    fill_in 'codigo', with: 'EMPINT01'
    find('#codigo').native.send_keys(:return)
    expect(page).to have_content('Empanada Carne', wait: 5)

    # Wait for auto-fill of medio de pago importe
    sleep 1

    # Verify medio importe was auto-filled
    within('#medio-pago-selector') do
      expect(find('.medio-pago-importe').value.to_f).to eq(200.0)
    end

    # Click confirm and accept the browser confirm dialog
    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    # Page should navigate and show success message
    expect(page).to have_content('confirmado correctamente', wait: 10)

    # Verify the pedido was confirmed in DB
    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true, estado_id: 3)
                            .order(id: :desc).first
    expect(pedido).to be_present
  end

  scenario 'edit a confirmed pedido and re-confirm successfully' do
    login_and_visit_vm

    # --- Step 1: Create and confirm a pedido ---
    fill_in 'codigo', with: 'EMPINT01'
    find('#codigo').native.send_keys(:return)
    expect(page).to have_content('Empanada Carne', wait: 5)
    sleep 1

    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end
    expect(page).to have_content('confirmado correctamente', wait: 10)

    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true, estado_id: 3)
                            .order(id: :desc).first
    expect(pedido).to be_present

    # --- Step 2: Click edit on the confirmed pedido ---
    within('#pedidos') do
      accept_confirm do
        find("a[href='#{edit_ventas_mostrador_pedido_path(pedido)}']").click
      end
    end

    # Pedido is back in editing mode with existing product
    expect(page).to have_content('Empanada Carne', wait: 5)
    sleep 1

    # --- Step 3: Re-confirm the edited pedido ---
    accept_confirm do
      click_button 'Confirmar e Imprimir (F10)'
    end

    # Should succeed without error
    expect(page).to have_content('confirmado correctamente', wait: 10)
    expect(page).not_to have_content('Error al Confirmar')

    # Verify pedido is confirmed again in DB
    pedido.reload
    expect(pedido.estado_id).to eq(3)
    expect(pedido.facturado).to be true
  end
end
