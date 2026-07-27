# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pedido Cliente Flow with Stock Movements', :js, type: :system do
  before do
    # Create Comprobantes::Tipo records needed for billing system
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
                     nombre: 'Test Store Stock Flow',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@store.com',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: true)

    # Don't create a local - use nil for single-location tienda
    @local = nil

    # Create cliente with cuenta corriente enabled
    @cliente = create(:cliente,
                      nombre: 'Test Cliente Stock',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: true,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta,
                     nombre: 'Test Account',
                     cliente: @cliente)

    # Create cliente user (no local for single-location tienda)
    @cliente_user = create(:usuario, :cliente,
                           login: 'clientestock',
                           password: 'password123',
                           password_confirmation: 'password123',
                           nombre: 'Cliente Stock User',
                           email: 'clientestock@example.com',
                           cuenta: @cuenta,
                           tienda_cliente: @tienda,
                           visualizando_tienda: @tienda)

    # Create category with stock enabled
    @categoria_stock = create(:categoria,
                              nombre: 'Bebidas',
                              tienda: @tienda,
                              stock_activo: true,
                              menu_diario: false)

    # Create dummy daily menu category to avoid SQL issue
    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    # Associate cliente with category
    @cliente.categorias << @categoria_stock unless @cliente.categorias.include?(@categoria_stock)
    @cliente.reload

    # Create products with stock
    @producto1 = create(:producto,
                        nombre: 'Agua Mineral 500ml',
                        codigo: 'AGU001',
                        descripcion: 'Agua mineral sin gas',
                        tienda: @tienda,
                        categoria: @categoria_stock,
                        discontinued_at: nil)

    @producto2 = create(:producto,
                        nombre: 'Coca Cola 500ml',
                        codigo: 'COC001',
                        descripcion: 'Gaseosa cola',
                        tienda: @tienda,
                        categoria: @categoria_stock,
                        discontinued_at: nil)

    # The products should have stocks auto-created by the after_create callback
    # since categoria has stock_activo: true
    # Now update the stocks to the desired amounts (with local_id: nil for single-location tienda)
    @stock1 = @producto1.stocks.find_or_create_by!(tienda: @tienda, local_id: nil)
    @stock1.update!(cantidad_actual: 50, cantidad_minima: 10, activo: true)

    @stock2 = @producto2.stocks.find_or_create_by!(tienda: @tienda, local_id: nil)
    @stock2.update!(cantidad_actual: 30, cantidad_minima: 5, activo: true)

    # Create general prices (no client-specific prices needed since listas_de_precio_privada = false)
    create(:precio,
           producto: @producto1,
           importe: 50.0,
           fecha_desde: 1.week.ago,
           fecha_hasta: 1.year.from_now)

    create(:precio,
           producto: @producto2,
           importe: 80.0,
           fecha_desde: 1.week.ago,
           fecha_hasta: 1.year.from_now)
  end

  scenario 'Cliente creates pedido, adds products, and stock is reduced after confirmation' do
    # Login as cliente user
    visit root_path

    fill_in 'username', with: 'clientestock'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'

    expect(page).to have_current_path(%r{/pedidos}, wait: 5)

    # Verify initial stock levels
    initial_stock1 = @stock1.reload.cantidad_actual
    initial_stock2 = @stock2.reload.cantidad_actual

    expect(initial_stock1).to eq(50)
    expect(initial_stock2).to eq(30)

    # Add products to cart
    expect(page).to have_css('.producto-venta', minimum: 2)

    expect(page).to have_content(@producto1.nombre)
    expect(page).to have_content(@producto2.nombre)

    producto1_card = page.all('.producto-venta').find { |card| card.text.include?(@producto1.nombre) }
    producto2_card = page.all('.producto-venta').find { |card| card.text.include?(@producto2.nombre) }

    expect(producto1_card).not_to be_nil
    expect(producto2_card).not_to be_nil

    # Add 5 units of producto1
    5.times do
      within(producto1_card) do
        find('a.mas').click
        sleep(0.3)
      end
    end

    # Add 3 units of producto2
    3.times do
      within(producto2_card) do
        find('a.mas').click
        sleep(0.3)
      end
    end

    # Finalize pedido
    carrito_button = page.find('a, button', text: /ir al carrito/i, match: :first)
    carrito_button.click

    expect(page).to have_current_path(%r{/pedidos/\d+/comprar}, wait: 5)
    expect(page).to have_content('Finalizar Compra')

    # Verify stock BEFORE confirmation (should not be reduced yet)
    stock1_before_confirm = @stock1.reload.cantidad_actual
    stock2_before_confirm = @stock2.reload.cantidad_actual

    expect(stock1_before_confirm).to eq(50)
    expect(stock2_before_confirm).to eq(30)

    # Confirm purchase
    confirmar_button = page.find('a, button', text: /finalizar compra/i, match: :first)
    confirmar_button.click

    # Wait for redirect after confirmation
    expect(page).not_to have_current_path(%r{/comprar}, wait: 10)

    # Verify stock AFTER confirmation (should be reduced)
    stock1_after_confirm = @stock1.reload.cantidad_actual
    stock2_after_confirm = @stock2.reload.cantidad_actual

    expect(stock1_after_confirm).to eq(45) # 50 - 5
    expect(stock2_after_confirm).to eq(27) # 30 - 3

    # Verify stock movements were created
    stock1_movements = @stock1.stock_movimientos.where(tipo: 'salida').order(created_at: :desc)
    stock2_movements = @stock2.stock_movimientos.where(tipo: 'salida').order(created_at: :desc)

    expect(stock1_movements.count).to be >= 1
    expect(stock2_movements.count).to be >= 1

    last_movement1 = stock1_movements.first
    expect(last_movement1.cantidad).to eq(5)
    expect(last_movement1.cantidad_anterior).to eq(50)
    expect(last_movement1.cantidad_nueva).to eq(45)
    expect(last_movement1.motivo).to eq('venta')
    expect(last_movement1.usuario_id).to be_nil

    last_movement2 = stock2_movements.first
    expect(last_movement2.cantidad).to eq(3)
    expect(last_movement2.cantidad_anterior).to eq(30)
    expect(last_movement2.cantidad_nueva).to eq(27)
    expect(last_movement2.motivo).to eq('venta')
    expect(last_movement2.usuario_id).to be_nil

    # Verify pedido state
    pedido = Pedidos::Pedido.last

    expect(pedido.estado_id).to be >= 2
    expect(pedido.cuenta_id).to eq(@cuenta.id)

    productos_solicitados = pedido.productos_solicitados
    expect(productos_solicitados.count).to eq(2)

    ps1 = productos_solicitados.find_by(producto_id: @producto1.id)
    ps2 = productos_solicitados.find_by(producto_id: @producto2.id)

    expect(ps1.cantidad).to eq(5)
    expect(ps2.cantidad).to eq(3)

    # Verify redirect
    expect(page).not_to have_current_path(%r{/pedidos/\d+/comprar})
  end

  scenario 'Stock validation prevents ordering more than available' do
    # Set producto1 stock to only 2 units
    @stock1.update!(cantidad_actual: 2)

    visit root_path
    fill_in 'username', with: 'clientestock'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'

    expect(page).to have_css('.producto-venta', wait: 5)

    # Try to add 3 units (more than available)
    producto1_card = page.find('.producto-venta', text: @producto1.nombre)

    3.times do |_i|
      within(producto1_card) do
        plus_button = find('a.mas')

        # After 2 clicks, the button should be disabled
        break if plus_button[:class].include?('disabled-stock')

        plus_button.click
        sleep(0.3)
      end
    end

    # Verify we couldn't add more than 2
    within(producto1_card) do
      quantity_input = find("input[data-productoid='#{@producto1.id}']")
      expect(quantity_input.value.to_i).to be <= 2
    end
  end
end
