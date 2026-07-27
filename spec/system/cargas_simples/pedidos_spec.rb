# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Carga Rápida de Pedidos', :js, type: :system do
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
                     nombre: 'Tienda Carga Rapida',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@carga.com',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    @cliente = create(:cliente,
                      nombre: 'Cliente Carga Rapida',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: true,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta,
                     nombre: 'Cuenta Carga Rapida',
                     cliente: @cliente)

    # Create admin user
    @admin = create(:usuario, :admin,
                    login: 'admincarga',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin Carga',
                    email: 'admincarga@example.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    # Create a client user who orders will be created for
    @cliente_user = create(:usuario, :cliente,
                           login: 'clientecarga',
                           password: 'password123',
                           password_confirmation: 'password123',
                           nombre: 'Cliente User Carga',
                           email: 'clientecarga@example.com',
                           cuenta: @cuenta,
                           tienda_cliente: @tienda,
                           visualizando_tienda: @tienda)

    # Create category
    @categoria = create(:categoria,
                        nombre: 'Alimentos',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    # Create dummy daily menu category
    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    # Associate cliente with category
    @cliente.categorias << @categoria unless @cliente.categorias.include?(@categoria)

    # Create products
    @producto1 = create(:producto,
                        nombre: 'Milanesa Napolitana',
                        codigo: 'MIL001',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    @producto2 = create(:producto,
                        nombre: 'Ensalada Caesar',
                        codigo: 'ENS001',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    @producto3 = create(:producto,
                        nombre: 'Agua Mineral',
                        codigo: 'AGU001',
                        tienda: @tienda,
                        categoria: @categoria,
                        discontinued_at: nil)

    # Create prices
    create(:precio, producto: @producto1, importe: 150.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    create(:precio, producto: @producto2, importe: 120.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    create(:precio, producto: @producto3, importe: 50.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  scenario 'admin loads the carga rápida page and sees form and pedido list' do
    visit root_path
    fill_in 'username', with: 'admincarga'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)

    visit cargas_simples_pedidos_path
    expect(page).to have_content('Carga Rápida', wait: 10)
    expect(page).to have_content('Nuevo Pedido')

    # The form elements should be present
    expect(page).to have_css('#pedido_tipo_pedido')
    expect(page).to have_css('#pedido_fecha')

    # Pedidos list section should be present
    expect(page).to have_content('Pedidos')
    expect(page).to have_content('Filtros')
  end

  scenario 'admin selects usuario and sees product fields appear' do
    visit root_path
    fill_in 'username', with: 'admincarga'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)

    visit cargas_simples_pedidos_path
    expect(page).to have_content('Carga Rápida', wait: 10)

    # Fill in a date first
    fecha_field = find('#pedido_fecha')
    fecha_field.set(Date.current.strftime('%d/%m/%Y'))

    # Select usuario via select2 AJAX (Select2 v3)
    find('#s2id_pedido_usuario_id .select2-choice').click
    find('.select2-drop-active .select2-input').set('Cliente User Carga')
    expect(page).to have_css('.select2-drop-active .select2-result-label', text: /Cliente User Carga/, wait: 10)
    find('.select2-drop-active .select2-result-label', text: /Cliente User Carga/, match: :first).click

    # Wait for AJAX cambiar_usuario to load product fields
    expect(page).to have_css('.productos_solicitados', wait: 10)
  end

  scenario 'admin creates a pedido rápido with products' do
    visit root_path
    fill_in 'username', with: 'admincarga'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)

    visit cargas_simples_pedidos_path
    expect(page).to have_content('Carga Rápida', wait: 10)

    # Fill date
    fecha_field = find('#pedido_fecha')
    fecha_field.set(Date.current.strftime('%d/%m/%Y'))

    # Select usuario (Select2 v3)
    find('#s2id_pedido_usuario_id .select2-choice').click
    find('.select2-drop-active .select2-input').set('Cliente User Carga')
    expect(page).to have_css('.select2-drop-active .select2-result-label', text: /Cliente User Carga/, wait: 10)
    find('.select2-drop-active .select2-result-label', text: /Cliente User Carga/, match: :first).click

    # Wait for product fields
    expect(page).to have_css('.productos_solicitados', wait: 10)

    # Select first product in the first row (Select2 v3)
    within('.productos_solicitados tbody tr:first-child') do
      find('.select2-container', match: :first).click
    end
    # Search in the global select2 dropdown
    find('.select2-drop-active .select2-input').set('Milanesa')
    expect(page).to have_css('.select2-drop-active .select2-result-label', text: /Milanesa/, wait: 10)
    find('.select2-drop-active .select2-result-label', text: /Milanesa/, match: :first).click

    # Set quantity (input has label: false, find by CSS)
    within('.productos_solicitados tbody tr:first-child') do
      find('input[id$="_cantidad"]', match: :first).fill_in(with: '3')
    end

    # Submit
    click_button 'Crear'

    # Should redirect with success message
    expect(page).to have_content('cargado correctamente', wait: 15)

    # Verify pedido appears in the list
    expect(page).to have_css('#pedidos-container table', wait: 5)
  end

  scenario 'tipo pedido toggle switches between usuario and cuenta modes' do
    visit root_path
    fill_in 'username', with: 'admincarga'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)

    visit cargas_simples_pedidos_path
    expect(page).to have_content('Carga Rápida', wait: 10)

    # Default is "Usuario" mode (value=1)
    expect(page).to have_select('pedido_tipo_pedido', selected: 'Usuario')
    expect(page).to have_css('.pedido_usuario_id:not(.hide)')

    # Switch to "Cuenta" mode
    select 'Cuenta', from: 'pedido_tipo_pedido'
    expect(page).to have_css('.pedido_usuario_id.hide', visible: false)
    expect(page).to have_css('.pedido_cuenta_id:not(.hide)')

    # Switch back to "Usuario" mode
    select 'Usuario', from: 'pedido_tipo_pedido'
    expect(page).to have_css('.pedido_usuario_id:not(.hide)')
  end

  context 'with existing pedidos' do
    before do
      # Create some pre-existing pedidos for the list
      3.times do |i|
        pedido = Pedidos::Pedido.new(
          autor: @admin, usuario: @cliente_user, cuenta: @cuenta,
          fecha: Date.current - i.days, estado_id: 1,
          tienda_id: @tienda.id
        )
        pedido.asignar_cuenta_manual
        pedido.cuenta = @cuenta
        pedido.no_validar_fecha = true
        pedido.save!
        ps = Productos::ProductoSolicitado.new(
          pedido: pedido, producto: @producto1,
          cantidad: i + 1, precio_unitario: 150.0
        )
        ps.save(validate: false)
        pedido.facturando
        pedido.aceptar! if pedido.pendiente?
      end
    end

    scenario 'pedidos list shows existing pedidos with correct data' do
      visit root_path
      fill_in 'username', with: 'admincarga'
      fill_in 'password', with: 'password123'
      click_button 'Iniciar sesión'
      expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)

      visit cargas_simples_pedidos_path
      expect(page).to have_content('Carga Rápida', wait: 10)

      # The pedidos list should show our pedidos
      within('#pedidos-container') do
        expect(page).to have_css('table#pedidos tbody tr', minimum: 3)
        expect(page).to have_content('Milanesa')
      end
    end
  end
end
