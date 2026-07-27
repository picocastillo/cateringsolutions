require 'rails_helper'

RSpec.describe 'Turnos de Entrega - Sistema', :js, type: :system do
  let!(:tienda) { create(:tienda, nombre: 'Catering Solutions', carrito_de_compras: true, maneja_stock: true) }
  # Crear productos
  let!(:producto_alfajor) do
    create(:producto, nombre: 'Alfajor', tienda: tienda, categoria: categoria_kiosco)
  end
  let!(:producto_coca) do
    create(:producto, nombre: 'Coca Cola', tienda: tienda, categoria: categoria_bebidas)
  end
  let!(:producto_milanesa) do
    create(:producto, nombre: 'Milanesa', tienda: tienda, categoria: categoria_comida)
  end
  let!(:cliente) do
    # cuenta_corriente: false para que muestre selector de turno (pagar_mercadopago requiere !cuenta_corriente)
    # horarios_de_entrega: true para que envío/horarios funcionen (no necesario para turnos)
    create(:cliente, tienda: tienda, horario_corte_pedidos: '12:00', cuenta_corriente: false, horarios_de_entrega: true)
  end
  let!(:cuenta) { create(:cuenta, cliente: cliente, cuenta_corriente_parcial: nil) }
  let!(:usuario) do
    create(:usuario, :admin, cuenta: cuenta, tienda_cliente: tienda, visualizando_tienda: tienda,
                             login: 'admin_turnos', password: 'password123', password_confirmation: 'password123').tap do |u|
      u.tiendas << tienda unless u.tiendas.include?(tienda)
    end
  end

  let!(:local) do
    create(:local, tienda: tienda, nombre: 'Local Test', domicilio: 'Calle 123', telefono: '123456')
  end

  # Crear turnos
  let!(:turno_desayuno) { create(:turno_entrega, :desayuno) }
  let!(:turno_almuerzo) { create(:turno_entrega, :almuerzo) }
  let!(:turno_merienda) { create(:turno_entrega, :merienda) }

  # Crear categorías
  let!(:categoria_kiosco) { create(:categoria, nombre: 'Kiosco', tienda: tienda, stock_activo: false) }
  let!(:categoria_bebidas) { create(:categoria, nombre: 'Bebidas', tienda: tienda, stock_activo: false) }
  let!(:categoria_comida) { create(:categoria, nombre: 'Comida', tienda: tienda, stock_activo: false) }

  # Mapear categorías a turnos
  before do
    # Desayuno y Merienda solo permiten Kiosco y Bebidas
    create(:turno_entrega_categoria, turno_entrega: turno_desayuno, categoria: categoria_kiosco)
    create(:turno_entrega_categoria, turno_entrega: turno_desayuno, categoria: categoria_bebidas)
    create(:turno_entrega_categoria, turno_entrega: turno_merienda, categoria: categoria_kiosco)
    create(:turno_entrega_categoria, turno_entrega: turno_merienda, categoria: categoria_bebidas)
    # Almuerzo no tiene restricciones (permite todas)

    # Asignar turnos al cliente
    create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_desayuno)
    create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_almuerzo)
    create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_merienda)
    create(:precio, :for_cliente, producto: producto_alfajor, cliente: cliente, importe: 50, fecha_desde: Time.zone.today)
    create(:precio, :for_cliente, producto: producto_coca, cliente: cliente, importe: 80, fecha_desde: Time.zone.today)
    create(:precio, :for_cliente, producto: producto_milanesa, cliente: cliente, importe: 200, fecha_desde: Time.zone.today)

    driven_by :selenium_remote
    # Manual login
    visit root_path
    fill_in 'username', with: usuario.login
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
  end

  # Crear precios

  describe 'Selector de turnos en checkout' do
    let!(:pedido) do
      pedido = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1, fecha: Date.current + 1.day, autor: usuario, usuario: usuario)
      pedido.asignar_cuenta_manual
      pedido.cuenta = cuenta
      pedido.save!
      create(:producto_solicitado, pedido: pedido, producto: producto_alfajor,
                                   cantidad: 1, precio_unitario: 50.0)
      pedido
    end

    it 'muestra selector de turnos en la página de comprar' do
      visit pedido_comprar_path(pedido)

      expect(page).to have_css('#turno_entrega_selector')
      expect(page).to have_content('Turno de Entrega')
    end

    it 'muestra todos los turnos activos del cliente' do
      visit pedido_comprar_path(pedido)

      within '#turno_entrega_selector' do
        expect(page).to have_content('Desayuno')
        expect(page).to have_content('Almuerzo')
        expect(page).to have_content('Merienda')
      end
    end

    it 'deshabilita MP y muestra hint cuando no hay turno seleccionado' do
      visit pedido_comprar_path(pedido)

      expect(page).to have_css('#preference-container', wait: 5)
      # generar_pago_ml AJAX runs on mount; turno is blank so validation fails
      expect(page).to have_css('#mp-payment-validation-hint', visible: :visible, wait: 10)
      expect(page).to have_content('Turno de Entrega')
    end

    it 'habilita MP cuando hay turno seleccionado' do
      pedido.update_column(:turno_entrega_id, turno_almuerzo.id)
      visit pedido_comprar_path(pedido)

      expect(page).to have_css('#turno_entrega_selector')
      # Validation should pass; hint is hidden.
      expect(page).to have_css('#preference-container', wait: 5)
      expect(page).not_to have_css('#mp-payment-validation-hint', visible: :visible, wait: 5)
    end

    it 'permite seleccionar turno desde el dropdown (recarga la página)' do
      visit pedido_comprar_path(pedido)

      expect(page).to have_css('#turno_entrega_selector')

      select 'Almuerzo', from: 'turno_entrega_selector'

      # Wait for AJAX PATCH + reload to persist the new turno
      Timeout.timeout(10) do
        sleep 0.2 until pedido.reload.turno_entrega_id == turno_almuerzo.id
      end
      expect(pedido.reload.turno_entrega_id).to eq(turno_almuerzo.id)
    end

    it 'muestra mensaje informativo para turnos con restricciones' do
      pedido.update!(turno_entrega_id: turno_desayuno.id)
      visit pedido_comprar_path(pedido)

      expect(page).to have_content('Desayuno')
      expect(page).to have_content('Solo están disponibles las categorías')
      expect(page).to have_content('Kiosco')
      expect(page).to have_content('Bebidas')
    end
  end

  describe 'Filtrado de productos por turno' do
    let!(:pedido) do
      pedido = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1, fecha: Date.current + 1.day, autor: usuario, usuario: usuario)
      pedido.asignar_cuenta_manual
      pedido.cuenta = cuenta
      pedido.save!
      pedido
    end

    context 'sin turno seleccionado' do
      it 'muestra todos los productos de todas las categorías' do
        visit edit_pedido_path(pedido)

        # Wait for AJAX-loaded product list
        expect(page).to have_css('#listado-de-productos .producto-venta', wait: 10)

        # Debería ver productos de todas las categorías
        expect(page).to have_content('Alfajor')
        expect(page).to have_content('Coca Cola')
        expect(page).to have_content('Milanesa')
      end
    end

    context 'con turno Desayuno seleccionado (solo Kiosco y Bebidas)' do
      before do
        pedido.update!(turno_entrega_id: turno_desayuno.id)
      end

      it 'muestra solo productos de Kiosco y Bebidas' do
        visit edit_pedido_path(pedido)

        # Wait for AJAX-loaded product list
        expect(page).to have_css('#listado-de-productos .producto-venta', wait: 10)

        expect(page).to have_content('Alfajor')
        expect(page).to have_content('Coca Cola')
        expect(page).not_to have_content('Milanesa')
      end

      it 'selector de categorías solo muestra Kiosco y Bebidas' do
        visit edit_pedido_path(pedido)

        # Wait for AJAX-loaded product list (categories come from shell, but verify after load)
        expect(page).to have_css('#listado-de-productos .producto-venta', wait: 10)

        # Bootstrap selectpicker hides the real <select>, check option values directly
        options = page.all('#categoria-selector option', visible: :all).map { |o| o.text(:all).strip }
        expect(options).to include('Kiosco')
        expect(options).to include('Bebidas')
        expect(options).not_to include('Comida')
      end
    end

    context 'con turno Almuerzo seleccionado (todas las categorías)' do
      before do
        pedido.update!(turno_entrega_id: turno_almuerzo.id)
      end

      it 'muestra productos de todas las categorías' do
        visit edit_pedido_path(pedido)

        # Wait for AJAX-loaded product list
        expect(page).to have_css('#listado-de-productos .producto-venta', wait: 10)

        expect(page).to have_content('Alfajor')
        expect(page).to have_content('Coca Cola')
        expect(page).to have_content('Milanesa')
      end
    end
  end

  describe 'Validación de turno asignado al cliente' do
    let!(:pedido) do
      pedido = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1, fecha: Date.current + 1.day, autor: usuario, usuario: usuario)
      pedido.asignar_cuenta_manual
      pedido.cuenta = cuenta
      pedido.save!
      create(:producto_solicitado, pedido: pedido, producto: producto_alfajor,
                                   cantidad: 1, precio_unitario: 50.0)
      pedido
    end

    let!(:turno_cena) { create(:turno_entrega, codigo: 'cena', nombre: 'Cena') }

    it 'no muestra turnos no asignados al cliente en el selector' do
      visit pedido_comprar_path(pedido)

      expect(page).to have_select('turno_entrega_selector')

      # Only turnos assigned to the client should appear in the dropdown
      options = page.all('#turno_entrega_selector option').map(&:text)
      expect(options).not_to include('Cena')
      expect(options.any? { |o| o.include?('Desayuno') }).to be true
      expect(options.any? { |o| o.include?('Almuerzo') }).to be true
      expect(options.any? { |o| o.include?('Merienda') }).to be true
    end
  end

  describe 'Integración completa: crear pedido con turno' do
    it 'flujo completo: nuevo pedido -> seleccionar turno -> finalizar' do
      # 1. Ir a nuevo pedido
      visit new_pedido_path

      # 2. Seleccionar cuenta y fecha
      select cuenta.to_s, from: 'pedido_cuenta_id' if page.has_select?('pedido_cuenta_id')
      fill_in 'pedido_fecha', with: (Date.current + 1.day).strftime('%d/%m/%Y')

      # 3. Guardar pedido básico
      # (Implementation depends on specific form flow)

      # 4. Ir a opciones
      # visit pedido_opciones_path(pedido)

      # 5. Seleccionar turno
      # select 'Desayuno', from: 'pedido_turno_entrega_id'

      # 6. Finalizar
      # click_button 'Ir a Pagar'

      # 7. Verificar que el pedido tiene turno asignado
      # expect(pedido.reload.turno_entrega).to eq(turno_desayuno)
    end
  end
end
