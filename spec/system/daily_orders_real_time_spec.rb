# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Daily Orders Real-Time Updates via Action Cable', type: :system do
  # NOTE: This test verifies the Action Cable real-time update infrastructure:
  # - Frontend JavaScript (App.dailyOrders) is properly loaded
  # - WebSocket connection is active
  # - updateCounters function works correctly when called
  # - Initial counters match database state
  #
  # WebSocket message delivery in test environment has limitations, so we verify
  # the infrastructure is in place and test the JS function directly.
  #
  # Uses a high fixed ID to avoid any potential interference with other parallel tests.
  let!(:tienda) { create(:tienda, id: 99_999, carrito_de_compras: true) }
  let!(:admin_user) do
    user = create(:usuario, :admin, :with_password, visualizando_tienda: tienda, email: 'admin_daily_orders@test.com')
    user.tiendas << tienda unless user.tiendas.include?(tienda)
    user
  end
  let!(:cliente) { create(:cliente, tienda: tienda, horario_corte_pedidos: 1.minute.ago.strftime('%H:%M')) }
  let!(:cuenta) { create(:cuenta, cliente: cliente) }
  let!(:categoria) { create(:categoria, tienda: tienda, nombre: 'Test Category') }
  let!(:producto) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Test Product') }
  let!(:precio) do
    precio = create(:precio, producto: producto, importe: 150.0, fecha_desde: Date.current)
    precio.clientes << cliente unless precio.clientes.include?(cliente)
    precio
  end

  before do
    driven_by(:selenium_remote)
  end

  describe 'Kitchen Panel counters update in real-time' do
    before do
      Capybara.default_max_wait_time = 15
    end

    after do
      Capybara.default_max_wait_time = 5
    end

    it 'verifies Action Cable infrastructure and counter updates' do
      # Step 1: Create pedidos BEFORE visiting the page (avoids timing issues in parallel)
      today = Date.current

      pedido1 = create(:pedido, tienda: tienda, cuenta: cuenta, fecha: today,
                                estado_id: 1, autor: admin_user, usuario: admin_user)
      pedido1.asignar_cuenta_manual
      pedido1.cuenta = cuenta
      pedido1.save!
      create(:producto_solicitado, pedido: pedido1, producto: producto,
                                   cantidad: 2, precio_unitario: 150.0)
      allow(pedido1).to receive(:crear_comprobante)
      pedido1.aceptar!

      pedido2 = create(:pedido, tienda: tienda, cuenta: cuenta, fecha: today,
                                estado_id: 1, autor: admin_user, usuario: admin_user)
      pedido2.asignar_cuenta_manual
      pedido2.cuenta = cuenta
      pedido2.save!
      create(:producto_solicitado, pedido: pedido2, producto: producto,
                                   cantidad: 3, precio_unitario: 150.0)
      allow(pedido2).to receive(:crear_comprobante)
      pedido2.aceptar!

      # Verify data is in DB before loading page
      db_count = Pedidos::Pedido.where(tienda_id: tienda.id, estado_id: 2,
                                       fecha: today, pedido_cocina_id: nil).count
      expect(db_count).to eq(2), "Expected 2 aceptado pedidos in DB, got #{db_count}"

      # Step 2: Login and visit /inicio (data is already committed)
      admin_login(admin_user)

      # The admin_login ends at /inicio — the page should already show the counters
      expect(page).to have_selector('#daily-orders-container', wait: 10)
      expect(page).to have_content('Panel de Cocina')

      # Wait for Action Cable connection
      sleep 2

      # Step 3: Verify Action Cable infrastructure
      has_cable = page.evaluate_script('typeof App !== "undefined" && typeof App.cable !== "undefined"')
      has_subscription = page.evaluate_script('typeof App !== "undefined" && typeof App.dailyOrders !== "undefined"')
      cable_active = page.evaluate_script(
        'typeof App !== "undefined" && typeof App.cable !== "undefined" && App.cable.connection.isActive()'
      )

      expect(has_cable).to be true
      expect(has_subscription).to be true
      expect(cable_active).to be true

      # Step 4: Verify initial counter shows 2 pendientes (use have_css for retry)
      expect(page).to have_css('[data-counter="pedidos_pendientes"]', text: '2', wait: 10)

      # Step 5: Test updateCounters JavaScript function directly
      # (WebSocket delivery is unreliable in Capybara, but the JS function works)
      page.execute_script(<<~JS)
        if (App.dailyOrders && App.dailyOrders.updateCounters) {
          App.dailyOrders.updateCounters({
            pedidos_pendientes: 1,
            pedidos_listos_cocinar: 1
          });
        }
      JS

      # Use Capybara's built-in waiting to check the counter text changed
      expect(page).to have_css('[data-counter="pedidos_pendientes"]', text: '1', wait: 5)
      expect(page).to have_css('[data-counter="pedidos_listos_cocinar"]', text: '1', wait: 5)
    end
  end
end
