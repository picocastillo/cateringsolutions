# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ventas Mostrador - Medio de Pago', :js, type: :system do
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
                     nombre: 'Tienda MedioPago',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@mediopago.com',
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
                    login: 'adminmediopago',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin MedioPago',
                    email: 'adminmediopago@example.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    @categoria = create(:categoria,
                        nombre: 'Productos MP',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    @cliente_cf.categorias << @categoria unless @cliente_cf.categorias.include?(@categoria)

    @producto = create(:producto,
                       nombre: 'Empanada Carne',
                       codigo: 'EMP001',
                       tienda: @tienda,
                       categoria: @categoria,
                       discontinued_at: nil)

    create(:precio, producto: @producto, importe: 200.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)

    # Login
    visit root_path
    fill_in 'username', with: 'adminmediopago'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    find('body', wait: 10) # Wait for login redirect
  end

  scenario 'medios de pago section is visible with default efectivo row' do
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)

    within('#medio-pago-selector') do
      expect(page).to have_content('Medios de Pago')
      expect(page).to have_select(nil, selected: 'Efectivo', count: 1)
    end
  end

  scenario 'auto-fills medio importe when single product added' do
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)

    # Add product
    fill_in 'codigo', with: 'EMP001'
    find('#codigo').native.send_keys(:return)
    expect(page).to have_content('Empanada Carne', wait: 5)

    # Wait for auto-fill of medio importe (fires on ajaxComplete with 200ms delay)
    sleep 1

    within('#medio-pago-selector') do
      importe_field = find('.medio-pago-importe')
      # autoFillSingleMedio should have filled with the total ($200.00)
      expect(importe_field.value.to_f).to eq(200.0)
      expect(find('.medio-pago-tipo').value).to eq('efectivo')
    end

    # Verify the pedido has the right total in the DB
    pedido = Pedidos::Pedido.where(tienda: @tienda, venta_mostrador: true, estado_id: 1)
                            .order(id: :desc).first
    expect(pedido).to be_present
    expect(pedido.importe_total.to_f).to eq(200.0)
  end

  scenario 'medio tipo change persists selection' do
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)

    # Add product
    fill_in 'codigo', with: 'EMP001'
    find('#codigo').native.send_keys(:return)
    expect(page).to have_content('Empanada Carne', wait: 5)

    sleep 1

    # Change medio to Débito and set importe
    within('#medio-pago-selector') do
      find('.medio-pago-tipo').select('Débito')
      find('.medio-pago-importe').set('200.00')

      # Verify selections stick
      expect(find('.medio-pago-tipo').value).to eq('debito')
      expect(find('.medio-pago-importe').value).to eq('200.00')
    end
  end

  scenario 'add button (+) inserts a new medio de pago row' do
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)

    within('#medio-pago-selector') do
      # Should start with 1 row
      expect(page).to have_css('#medios-pago-rows .fields', count: 1)

      # Click the + button
      find('a.add_nested_fields').click

      # Should now have 2 rows
      expect(page).to have_css('#medios-pago-rows .fields', count: 2)

      # Second row should have a tipo dropdown
      rows = all('#medios-pago-rows .fields')
      expect(rows[1]).to have_css('.medio-pago-tipo')
      expect(rows[1]).to have_css('.medio-pago-importe')
    end
  end

  scenario 'remove button (-) hides a medio de pago row' do
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)

    within('#medio-pago-selector') do
      # Add a second row first
      find('a.add_nested_fields').click
      expect(page).to have_css('#medios-pago-rows .fields', count: 2)

      # Click remove on the second row
      rows = all('#medios-pago-rows .fields')
      rows[1].find('a.remove_nested_fields').click

      # Second row should be hidden
      expect(page).to have_css('#medios-pago-rows .fields', visible: true, count: 1)
    end
  end

  scenario 'medios de pago rows persist after adding a product' do
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)

    # Verify initial medio exists
    within('#medio-pago-selector') do
      expect(page).to have_css('#medios-pago-rows .fields', count: 1)
    end

    # Add a product via barcode
    fill_in 'codigo', with: 'EMP001'
    find('#codigo').native.send_keys(:return)
    expect(page).to have_content('Empanada Carne', wait: 5)

    # Medio de pago row should still be visible after AJAX re-render
    within('#medio-pago-selector') do
      expect(page).to have_css('#medios-pago-rows .fields', visible: true, count: 1)
      expect(page).to have_select(nil, selected: 'Efectivo')
    end
  end

  scenario 'split payment: add second medio and both have correct values' do
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)

    # Add product ($200 total)
    fill_in 'codigo', with: 'EMP001'
    find('#codigo').native.send_keys(:return)
    expect(page).to have_content('Empanada Carne', wait: 5)
    sleep 1

    # Add second medio de pago row
    within('#medio-pago-selector') do
      find('a.add_nested_fields').click
      expect(page).to have_css('#medios-pago-rows .fields', count: 2)

      rows = all('#medios-pago-rows .fields')

      # First: efectivo $100
      rows[0].find('.medio-pago-importe').set('100.00')

      # Second: debito $100
      rows[1].find('.medio-pago-tipo').select('Débito')
      rows[1].find('.medio-pago-importe').set('100.00')

      # Verify values persisted in fields
      expect(rows[0].find('.medio-pago-importe').value).to eq('100.00')
      expect(rows[1].find('.medio-pago-importe').value).to eq('100.00')
      expect(rows[1].find('.medio-pago-tipo').value).to eq('debito')
    end
  end
end
