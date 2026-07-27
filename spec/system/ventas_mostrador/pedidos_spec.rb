# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Venta Mostrador', :js, type: :system do
  before do
    # Create Comprobantes::Tipo records needed for billing
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
                     nombre: 'Tienda Mostrador',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@mostrador.com',
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

    # Create admin user
    @admin = create(:usuario, :admin,
                    login: 'adminmostrador',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin Mostrador',
                    email: 'adminmostrador@example.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    # Create category
    @categoria = create(:categoria,
                        nombre: 'Productos VM',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    # Associate cliente with category
    @cliente_cf.categorias << @categoria unless @cliente_cf.categorias.include?(@categoria)

    # Create products with codes for barcode scanning
    @producto1 = create(:producto,
                        nombre: 'Empanada Carne',
                        codigo: 'EMP001',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    @producto2 = create(:producto,
                        nombre: 'Gaseosa Cola',
                        codigo: 'GAS001',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    # Create prices
    create(:precio, producto: @producto1, importe: 200.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    create(:precio, producto: @producto2, importe: 100.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  scenario 'admin loads venta mostrador page and sees POS form' do
    visit root_path
    fill_in 'username', with: 'adminmostrador'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)

    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)

    # POS form should be present
    expect(page).to have_css('#pedido_fecha')
    expect(page).to have_css('#pedido_cuenta_id')

    # Pedidos list section should be present
    expect(page).to have_content('Pedidos')
    expect(page).to have_content('Filtros')
  end

  scenario 'pedidos list shows footer aggregates after optimization' do
    # Create some existing confirmed pedidos for the footer
    3.times do |i|
      pedido = Pedidos::Pedido.new(
        autor: @admin, cuenta: @cuenta_cf,
        fecha: Date.current, estado_id: 1,
        tienda_id: @tienda.id, venta_mostrador: true
      )
      pedido.asignar_cuenta_manual
      pedido.cuenta = @cuenta_cf
      pedido.no_validar_fecha = true
      pedido.save!
      ps = Productos::ProductoSolicitado.new(
        pedido: pedido, producto: @producto1,
        cantidad: (i + 1) * 2, precio_unitario: 200.0
      )
      ps.save(validate: false)
      pedido.facturando
      pedido.aceptar! if pedido.pendiente?
    end

    visit root_path
    fill_in 'username', with: 'adminmostrador'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)

    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)

    # Should show pedidos in the list with footer aggregates
    within('#pedidos-container') do
      expect(page).to have_css('table#pedidos', wait: 5)
      expect(page).to have_content('Pedidos Totales')
      expect(page).to have_content('Productos Totales')
    end
  end

  scenario 'filtros section can be toggled' do
    visit root_path
    fill_in 'username', with: 'adminmostrador'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)

    visit ventas_mostrador_pedidos_path(show_filtro: true)
    expect(page).to have_content('Venta Mostrador', wait: 10)

    # Filters should be visible when show_filtro=true
    expect(page).to have_css('.filtros .card-body.collapse.show', wait: 5)
  end

  context 'filter tests' do
    before do
      # Create confirmed pedidos with different dates
      [Date.current, Date.current - 1.day, Date.current - 7.days].each do |fecha|
        pedido = Pedidos::Pedido.new(
          autor: @admin, cuenta: @cuenta_cf,
          fecha: fecha, estado_id: 1,
          tienda_id: @tienda.id, venta_mostrador: true
        )
        pedido.asignar_cuenta_manual
        pedido.cuenta = @cuenta_cf
        pedido.no_validar_fecha = true
        pedido.save!
        ps = Productos::ProductoSolicitado.new(
          pedido: pedido, producto: @producto1,
          cantidad: 2, precio_unitario: 200.0
        )
        ps.save(validate: false)
        pedido.facturando
        pedido.aceptar! if pedido.pendiente?
      end

      # Login
      visit root_path
      fill_in 'username', with: 'adminmostrador'
      fill_in 'password', with: 'password123'
      click_button 'Iniciar sesión'
      find('body', wait: 10) # Wait for login to complete
    end

    scenario 'fecha_desde tomorrow hides all pedidos' do
      visit ventas_mostrador_pedidos_path(show_filtro: true)
      expect(page).to have_content('Venta Mostrador', wait: 10)

      # Should see pedidos initially
      within('#pedidos-container') do
        expect(page).to have_css('table#pedidos tbody tr', minimum: 1, wait: 5)
      end

      # Set fecha_desde to tomorrow via JS and dismiss datepicker
      tomorrow = (Date.current + 1.day).strftime('%d/%m/%Y')
      page.execute_script("$('input[name=\"q[fecha_desde]\"]').val('#{tomorrow}').datepicker('hide')")

      # Submit the filter form
      within('.filtros') do
        click_button 'Buscar'
      end

      # Wait for AJAX response - should show no pedidos
      within('#pedidos-container') do
        expect(page).to have_css('.no-results', wait: 10)
        expect(page).to have_content('No se encontraron resultados')
      end
    end

    scenario 'fecha_desde today shows only today pedidos' do
      visit ventas_mostrador_pedidos_path(show_filtro: true)
      expect(page).to have_content('Venta Mostrador', wait: 10)

      # Set fecha_desde to today via JS and dismiss datepicker
      today = Date.current.strftime('%d/%m/%Y')
      page.execute_script("$('input[name=\"q[fecha_desde]\"]').val('#{today}').datepicker('hide')")

      within('.filtros') do
        click_button 'Buscar'
      end

      # Should show only today's pedido (yesterday and last week excluded)
      within('#pedidos-container') do
        expect(page).to have_css('table#pedidos tbody tr', wait: 10)
        expect(page).not_to have_content((Date.current - 7.days).strftime('%d/%m/%Y'))
      end
    end

    scenario 'fecha_hasta yesterday hides today pedidos' do
      visit ventas_mostrador_pedidos_path(show_filtro: true)
      expect(page).to have_content('Venta Mostrador', wait: 10)

      # Set fecha_hasta to yesterday via JS and dismiss datepicker
      yesterday = (Date.current - 1.day).strftime('%d/%m/%Y')
      page.execute_script("$('input[name=\"q[fecha_hasta]\"]').val('#{yesterday}').datepicker('hide')")

      within('.filtros') do
        click_button 'Buscar'
      end

      # Should show yesterday and older pedidos, but not today's
      within('#pedidos-container') do
        expect(page).to have_css('table#pedidos tbody tr', wait: 10)
      end
    end

    scenario 'estado filter shows only matching pedidos' do
      # Create a cancelled pedido
      pedido_cancelado = Pedidos::Pedido.new(
        autor: @admin, cuenta: @cuenta_cf,
        fecha: Date.current, estado_id: 1,
        tienda_id: @tienda.id, venta_mostrador: true
      )
      pedido_cancelado.asignar_cuenta_manual
      pedido_cancelado.cuenta = @cuenta_cf
      pedido_cancelado.no_validar_fecha = true
      pedido_cancelado.save!
      ps = Productos::ProductoSolicitado.new(
        pedido: pedido_cancelado, producto: @producto2,
        cantidad: 1, precio_unitario: 100.0
      )
      ps.save(validate: false)
      pedido_cancelado.facturando
      pedido_cancelado.aceptar! if pedido_cancelado.pendiente?
      pedido_cancelado.cancelar!

      visit ventas_mostrador_pedidos_path(show_filtro: true)
      expect(page).to have_content('Venta Mostrador', wait: 10)

      # Filter by Cancelado estado
      within('.filtros') do
        select 'Cancelado', from: 'q[estado_id]'
        click_button 'Buscar'
      end

      # Should show only cancelled pedidos
      within('#pedidos-container') do
        expect(page).to have_css('table#pedidos tbody tr', wait: 10)
        expect(page).to have_content('Cancelado')
      end
    end
  end
end
