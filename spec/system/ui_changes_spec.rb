require 'rails_helper'

RSpec.describe 'UI Changes', :js, type: :system do
  before do
    @tienda = create(:tienda,
                     nombre: 'Test Tienda',
                     carrito_de_compras: true,
                     venta_mostrador: true)

    @admin = create(:usuario, :admin, :with_password,
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    @categoria = create(:categoria, tienda: @tienda, nombre: 'Comidas')
  end

  describe 'Producto show page' do
    before do
      @cliente = create(:cliente, tienda: @tienda, nombre: 'EMPRESA MAYUSCULAS')
      @cuenta = create(:cuenta, cliente: @cliente)

      @producto = create(:producto,
                         nombre: 'Milanesa Napolitana',
                         tienda: @tienda,
                         categoria: @categoria)

      # Vigente price with client association
      precio_cliente = create(:precio,
                              producto: @producto,
                              importe: 500.0,
                              fecha_desde: Date.current,
                              fecha_hasta: 1.year.from_now)
      precio_cliente.clientes << @cliente

      # Vigente price without client (general)
      create(:precio,
             producto: @producto,
             importe: 400.0,
             fecha_desde: Date.current,
             fecha_hasta: 1.year.from_now)

      # Old expired price
      create(:precio,
             producto: @producto,
             importe: 300.0,
             fecha_desde: 2.years.ago,
             fecha_hasta: 1.year.ago)
    end

    it 'shows precios without tab navigation' do
      admin_login(@admin, 'password123')
      visit producto_path(@producto)

      # Should show the precios content directly without tabs
      expect(page).not_to have_css('ul.nav.nav-tabs')
      expect(page).not_to have_css('a[data-toggle="tab"]')

      # Should show precios vigentes section
      expect(page).to have_content('Precios Vigentes')
    end

    it 'displays client names with titleize formatting' do
      admin_login(@admin, 'password123')
      visit producto_path(@producto)

      # The client name "EMPRESA MAYUSCULAS" should display as "Empresa Mayusculas"
      expect(page).to have_content('Empresa Mayusculas')
      expect(page).not_to have_content('EMPRESA MAYUSCULAS')
    end

    it 'shows precios anteriores in collapsible section' do
      admin_login(@admin, 'password123')
      visit producto_path(@producto)

      expect(page).to have_content('Precios Anteriores')
      expect(page).to have_css('#precios-historicos', visible: :all)
    end
  end

  describe 'Pedido purchase limit' do
    before do
      @cliente = create(:cliente,
                        tienda: @tienda,
                        nombre: 'Cliente Test',
                        cuenta_corriente: true,
                        limite_compra_pesos: 1000.00)
      @cuenta = create(:cuenta, cliente: @cliente)

      @producto = create(:producto, tienda: @tienda, categoria: @categoria, nombre: 'Producto Caro')
      create(:precio, producto: @producto, importe: 600.0, fecha_desde: Date.current, fecha_hasta: 1.year.from_now)
    end

    def create_pedido_with_total(cantidad)
      pedido = create(:pedido,
                      tienda: @tienda,
                      cuenta: @cuenta,
                      autor: @admin,
                      usuario: @admin,
                      fecha: Date.current,
                      estado_id: 1)
      pedido.asignar_cuenta_manual
      pedido.cuenta = @cuenta
      pedido.save!
      create(:producto_solicitado,
             pedido: pedido,
             producto: @producto,
             cantidad: cantidad,
             precio_unitario: 600.0)
      pedido
    end

    context 'on the pedido show page' do
      it 'shows limit warning when total exceeds purchase limit' do
        # 600 * 2 = 1200 > 1000 limit
        pedido = create_pedido_with_total(2)

        admin_login(@admin, 'password123')
        visit pedido_path(pedido)

        expect(page).to have_content('supera el límite diario de compra')
        expect(page).not_to have_link('Ir al Carrito')
      end

      it 'does not show limit warning when total is within limit' do
        # 600 * 1 = 600 < 1000 limit
        pedido = create_pedido_with_total(1)

        admin_login(@admin, 'password123')
        visit pedido_path(pedido)

        expect(page).not_to have_content('supera el límite diario de compra')
        # On show page, should see 'Finalizar Compra' button (not 'Ir al Carrito')
        expect(page).to have_link('Finalizar Compra')
      end
    end

    context 'when finalizing a pedido' do
      it 'blocks finalization when limit is exceeded' do
        # 600 * 2 = 1200 > 1000 limit
        pedido = create_pedido_with_total(2)

        admin_login(@admin, 'password123')

        # POST to finalizar using JavaScript (finalizar is a POST route)
        visit pedido_path(pedido)
        page.execute_script <<~JS
          var form = document.createElement('form');
          form.method = 'POST';
          form.action = '/pedidos/#{pedido.id}/finalizar';
          var csrf = document.querySelector('meta[name="csrf-token"]');
          if (csrf) {
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = 'authenticity_token';
            input.value = csrf.content;
            form.appendChild(input);
          }
          document.body.appendChild(form);
          form.submit();
        JS

        # Should redirect back with error about limit
        expect(page).to have_content('supera el límite diario de compra', wait: 10)

        # Pedido should remain pending
        pedido.reload
        expect(pedido.estado_id).to eq(1)
      end
    end
  end

  describe 'Cliente dolar cotization display' do
    before do
      Cotizaciones::Dolar.create!(fecha: Date.current, precio_venta: 1150.50, precio_compra: 1145.0)
      @cliente = create(:cliente,
                        tienda: @tienda,
                        nombre: 'Cliente Dolar',
                        cuenta_corriente: true,
                        limite_compra_dolares: 500.00)
      create(:cuenta, cliente: @cliente)
    end

    it 'shows dolar cotization in the edit form hint' do
      admin_login(@admin, 'password123')
      visit edit_cliente_path(@cliente)

      # The hint should show current cotization
      expect(page).to have_content('Cotización actual: $1150.50')
    end

    it 'shows dolar equivalence in pesos on the edit form' do
      admin_login(@admin, 'password123')
      visit edit_cliente_path(@cliente)

      # The hint should include cotización info
      expect(page).to have_content('Cotización actual')
      expect(page).to have_content('1150.50')
    end

    it 'shows dolar limit with cotization on the show page' do
      admin_login(@admin, 'password123')
      visit cliente_path(@cliente)

      expect(page).to have_content('Límite de compra en dólares')
      expect(page).to have_content('US$')
      expect(page).to have_content('500')
      # Should show cotization and pesos equivalent
      expect(page).to have_content('Cotiz: $1150.50')
    end

    context 'without dolar limit' do
      before do
        @cliente_sin_limite = create(:cliente,
                                     tienda: @tienda,
                                     nombre: 'Cliente Sin Limite')
        create(:cuenta, cliente: @cliente_sin_limite)
      end

      it 'does not show dolar info on show page' do
        admin_login(@admin, 'password123')
        visit cliente_path(@cliente_sin_limite)

        expect(page).not_to have_content('Límite de compra en dólares')
        expect(page).not_to have_content('US$')
      end
    end

    context 'with pesos limit only' do
      before do
        @cliente_pesos = create(:cliente,
                                tienda: @tienda,
                                nombre: 'Cliente Pesos',
                                limite_compra_pesos: 50_000.00)
        create(:cuenta, cliente: @cliente_pesos)
      end

      it 'shows pesos limit on show page without dolar info' do
        admin_login(@admin, 'password123')
        visit cliente_path(@cliente_pesos)

        expect(page).to have_content('Límite de compra')
        expect(page).not_to have_content('US$')
      end
    end
  end

  describe 'Inicio page charts' do
    around do |example|
      original = ENV.fetch('DISABLED_CHARTS', nil)
      ENV['DISABLED_CHARTS'] = 'false'
      example.run
    ensure
      ENV['DISABLED_CHARTS'] = original
    end

    it 'loads the stats widget containers (lazy-loaded)' do
      admin_login(@admin, 'password123')
      visit '/inicio'

      expect(page).to have_css('#widget-stats_top_productos', wait: 10)
      expect(page).to have_css('#widget-stats_top_menus_diarios')
      expect(page).to have_css('#widget-stats_usuarios_chart')
    end

    it 'renders the Productos por Mes chart when data exists' do
      # Create some historical pedido data
      @cliente = create(:cliente, tienda: @tienda)
      @cuenta = create(:cuenta, cliente: @cliente)
      @producto = create(:producto, tienda: @tienda, categoria: @categoria)
      create(:precio, producto: @producto, importe: 100.0, fecha_desde: 1.year.ago)

      5.times do |i|
        pedido = create(:pedido,
                        tienda: @tienda,
                        cuenta: @cuenta,
                        autor: @admin,
                        usuario: @admin,
                        fecha: (i + 1).months.ago,
                        estado_id: 1)
        ps = Productos::ProductoSolicitado.new(
          pedido: pedido,
          producto: @producto,
          cantidad: rand(1..10),
          precio_unitario: 100.0
        )
        ps.save(validate: false)
        pedido.update_column(:estado_id, 3)
      end

      admin_login(@admin, 'password123')

      # Clear any cached widget data from previous tests so this run sees the
      # pedidos we just created.
      Rails.cache.clear

      visit '/inicio'

      # Wait for the lazy-loaded widget container, then for AJAX to populate it
      expect(page).to have_css('#widget-stats_usuarios_chart', wait: 10)
      expect(page).to have_no_text('Cargando...', wait: 30)

      # The chart card should render with its title once data is loaded.
      # If empty (cache race), reload once and re-check.
      unless page.has_content?('Productos por Mes', wait: 5)
        visit '/inicio'
        expect(page).to have_no_text('Cargando...', wait: 30)
      end
      expect(page).to have_content('Productos por Mes', wait: 15)
    end
  end
end
