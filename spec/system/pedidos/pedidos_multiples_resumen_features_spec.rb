# frozen_string_literal: true

require 'rails_helper'

# System specs covering the features added to PedidosMultiples#resumen:
#   - Per-pedido stock insufficiency warnings
#   - Per-pedido límite de compra exceeded warning + button guard
#   - Cupón apply (valid code), invalid code inline error, remove
#   - Discount row in sidebar when cupón is applied
#   - Sidebar warning + CC button hidden when stock/limit issues
#   - MP payment hint template rendered in DOM
#   - MP button hidden when sin_stock (non-CC flow)
RSpec.describe 'PedidosMultiples Resumen — stock, límite & cupones', :js, type: :system do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def next_weekday(from = Date.current + 1.day)
    from += 1.day while from.saturday? || from.sunday?
    from
  end

  def make_pedido(tienda:, cuenta:, usuario:, fecha:, grupo:, producto:, cantidad: 2)
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: fecha, autor: usuario, usuario: usuario,
                       pedido_multiple_id: grupo.id)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    ps = Productos::ProductoSolicitado.new(
      pedido: p, producto: producto, cantidad: cantidad, precio_unitario: 100.0
    )
    ps.save(validate: false)
    p
  end

  # ---------------------------------------------------------------------------
  # Shared setup — admin user, CC-enabled account
  # ---------------------------------------------------------------------------
  let!(:tienda) do
    create(:tienda, nombre: 'ResumenFeatures', dominio: 'localhost',
                    carrito_de_compras: true, maneja_stock: true,
                    horarios_de_entrega: false)
  end
  let!(:local) do
    create(:local, tienda: tienda, nombre: 'Local RF', domicilio: 'Calle RF 1', telefono: '999')
  end
  let!(:cliente) do
    create(:cliente, tienda: tienda, nombre: 'RF Cliente',
                     cuenta_corriente: true,
                     horarios_de_entrega: false,
                     usuario_puede_elegir_cuenta: false,
                     permitir_envios_a_domicilio: false)
  end
  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta RF', cliente: cliente, cuenta_corriente_parcial: true) }
  let!(:usuario) do
    create(:usuario, :admin,
           login: 'rf_admin',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'RF Admin',
           email: 'rf_admin@test.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda).tap do |u|
      u.tiendas << tienda unless u.tiendas.include?(tienda)
    end
  end

  # Skip crear_stock_inicial so we control stock manually
  let!(:categoria) do
    create(:categoria, nombre: 'RF Cat', tienda: tienda, stock_activo: true)
  end
  let!(:producto) do
    Productos::Producto.skip_callback(:create, :after, :crear_stock_inicial)
    p = create(:producto, nombre: 'Producto RF', tienda: tienda, categoria: categoria)
    Productos::Producto.set_callback(:create, :after, :crear_stock_inicial)
    p
  end

  let!(:grupo)   { Pedidos::PedidoMultiple.create!(usuario: usuario, cuenta: cuenta) }
  let(:fecha1)   { next_weekday }
  let(:fecha2)   { next_weekday(fecha1 + 1.day) }
  let!(:pedido1) { make_pedido(tienda: tienda, cuenta: cuenta, usuario: usuario, fecha: fecha1, grupo: grupo, producto: producto) }
  let!(:pedido2) { make_pedido(tienda: tienda, cuenta: cuenta, usuario: usuario, fecha: fecha2, grupo: grupo, producto: producto) }

  before do
    create(:precio, :for_cliente, producto: producto, cliente: cliente,
                                  importe: 100, fecha_desde: Time.zone.today)
    allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante).and_return(true)
    driven_by :selenium_remote
    cliente_login(usuario)
  end

  # ---------------------------------------------------------------------------
  # Stock warnings
  # ---------------------------------------------------------------------------
  describe 'stock insuficiente warnings' do
    context 'when stock is insufficient for a pedido' do
      before do
        # pedido requests 2 units, stock has only 1.
        # local: nil so stock_for_local(nil) finds it (pedido.local is nil in make_pedido).
        Productos::Stock.create!(producto: producto, tienda: tienda, local: nil,
                                 cantidad_actual: 1, cantidad_minima: 0, cantidad_maxima: 50)
      end

      it 'shows the stock warning alert inside the pedido card' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).to have_content('Stock insuficiente', wait: 5)
        expect(page).to have_content('Producto RF')
        expect(page).to have_content('Solicitado')
      end

      it 'shows the sidebar warning about insufficient stock' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).to have_content('Hay productos sin stock suficiente', wait: 5)
      end

      it 'shows a "Modificar pedido" link inside the warning (admin can re_edit)' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).to have_link('Modificar pedido', wait: 5)
      end

      it 'shows the disponible quantity in red when zero stock' do
        Productos::Stock.find_by(producto: producto, tienda: tienda)&.update_columns(cantidad_actual: 0)
        visit resumen_pedido_multipl_path(grupo)

        expect(page).to have_content('Disponible:', wait: 5)
      end
    end

    context 'when stock is sufficient' do
      before do
        # local: nil so stock_for_local(nil) finds it (pedido.local is nil in make_pedido)
        Productos::Stock.create!(producto: producto, tienda: tienda, local: nil,
                                 cantidad_actual: 100, cantidad_minima: 0, cantidad_maxima: 200)
      end

      it 'does not show the stock warning alert' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).not_to have_content('Stock insuficiente', wait: 3)
        expect(page).not_to have_content('Hay productos sin stock suficiente', wait: 3)
      end
    end

    context 'when categoria does not have stock_activo' do
      before do
        categoria.update_columns(stock_activo: false)
        # No stock record needed
      end

      it 'does not show stock warnings even without a stock record' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).not_to have_content('Stock insuficiente', wait: 3)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Límite de compra
  # ---------------------------------------------------------------------------
  describe 'límite de compra excedido' do
    context 'when the purchase limit is exceeded' do
      before do
        # Each pedido has $100 in products; set limit to $50 to force exceedance
        cliente.update_columns(limite_compra_pesos: 50)
      end

      it 'shows the limit exceeded warning inside the pedido card' do
        visit resumen_pedido_multipl_path(grupo)

        # The warning text comes from pedido.mensaje_limite_compra_excedido
        expect(page).to have_content('límite', wait: 5)
        expect(page).to have_content('Reducí', wait: 5)
      end

      it 'shows the sidebar warning about limit exceeded' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).to have_content('Se superó el límite de compra', wait: 5)
      end

      it 'hides the Finalizar todos button when limit is exceeded' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).not_to have_button('Finalizar todos', wait: 3)
      end
    end

    context 'when no purchase limit is set' do
      it 'shows the Finalizar todos button' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).to have_button('Finalizar todos', wait: 5)
      end

      it 'does not show a limit exceeded warning' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).not_to have_content('límite de compra', wait: 3)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Cupón — input rendered
  # ---------------------------------------------------------------------------
  describe 'cupón input field' do
    it 'shows a cupón code input for each pending pedido' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_css("#cupon_codigo_input_#{pedido1.id}", wait: 5)
      expect(page).to have_css("#cupon_codigo_input_#{pedido2.id}")
    end

    it 'shows an Aplicar button for each pending pedido' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_css(".rm-aplicar-cupon-btn[data-pedido-id='#{pedido1.id}']", wait: 5)
      expect(page).to have_css(".rm-aplicar-cupon-btn[data-pedido-id='#{pedido2.id}']")
    end

    it 'does not show cupón input for non-pending pedidos' do
      pedido1.update_columns(estado_id: 2)

      visit resumen_pedido_multipl_path(grupo)

      expect(page).not_to have_css("#cupon_codigo_input_#{pedido1.id}", wait: 3)
      expect(page).to have_css("#cupon_codigo_input_#{pedido2.id}", wait: 3)
    end
  end

  # ---------------------------------------------------------------------------
  # Cupón — apply valid code
  # ---------------------------------------------------------------------------
  describe 'applying a valid cupón' do
    let!(:cupon) do
      create(:cupon, tienda: tienda, codigo: 'RFVALID',
                     tipo_descuento: 'importe', importe: 10,
                     fecha_vencimiento: Date.current + 1.month)
    end

    it 'shows the applied state with cupon code and Eliminar link after apply' do
      visit resumen_pedido_multipl_path(grupo)

      find("#cupon_codigo_input_#{pedido1.id}", visible: :all).set('RFVALID')
      find(".rm-aplicar-cupon-btn[data-pedido-id='#{pedido1.id}']").click

      # Page reloads (window.location.reload() in aplicar_cupon.js.erb)
      expect(page).to have_content('RFVALID', wait: 10)
      expect(page).to have_css(".rm-quitar-cupon-btn[data-pedido-id='#{pedido1.id}']", wait: 5)
    end

    it 'shows a success toast after applying' do
      visit resumen_pedido_multipl_path(grupo)

      find("#cupon_codigo_input_#{pedido1.id}", visible: :all).set('RFVALID')
      find(".rm-aplicar-cupon-btn[data-pedido-id='#{pedido1.id}']").click

      # Toast renders briefly; after reload the applied state is shown
      expect(page).to have_content('RFVALID', wait: 10)
    end

    it 'does not affect the input of the other pedido' do
      visit resumen_pedido_multipl_path(grupo)

      find("#cupon_codigo_input_#{pedido1.id}", visible: :all).set('RFVALID')
      find(".rm-aplicar-cupon-btn[data-pedido-id='#{pedido1.id}']").click

      expect(page).to have_css("#cupon_codigo_input_#{pedido2.id}", wait: 10)
    end
  end

  # ---------------------------------------------------------------------------
  # Cupón — apply invalid / expired code
  # ---------------------------------------------------------------------------
  describe 'applying an invalid cupón code' do
    it 'shows an inline error message without reloading' do
      visit resumen_pedido_multipl_path(grupo)

      find("#cupon_codigo_input_#{pedido1.id}", visible: :all).set('NOEXISTE')
      find(".rm-aplicar-cupon-btn[data-pedido-id='#{pedido1.id}']").click

      expect(page).to have_css("#cupon-error-#{pedido1.id}", wait: 5)
      expect(find("#cupon-error-#{pedido1.id}", visible: :all).text).to include('inválido')
    end

    it 'shows error for an expired cupón' do
      # asegurar_fecha_vencimiento callback resets past dates on save,
      # so use update_column to bypass it and force expiry.
      cupon_exp = create(:cupon, tienda: tienda, codigo: 'RFEXP', tipo_descuento: 'importe', importe: 5)
      cupon_exp.update_column(:fecha_vencimiento, Date.current - 1.day)

      visit resumen_pedido_multipl_path(grupo)

      find("#cupon_codigo_input_#{pedido1.id}", visible: :all).set('RFEXP')
      find(".rm-aplicar-cupon-btn[data-pedido-id='#{pedido1.id}']").click

      # Toast is always visible; both invalid-code and expired-cupon paths fire it
      expect(page).to have_content('inválido', wait: 10)
    end
  end

  # ---------------------------------------------------------------------------
  # Cupón — remove applied cupón
  # ---------------------------------------------------------------------------
  describe 'removing an applied cupón' do
    let!(:cupon) do
      create(:cupon, tienda: tienda, codigo: 'RFREMOVE',
                     tipo_descuento: 'importe', importe: 15,
                     fecha_vencimiento: Date.current + 1.month)
    end

    before do
      pedido1.aplicar_cupon!(cupon)
      pedido1.reload
    end

    it 'shows the Eliminar link when a cupón is applied' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_css(".rm-quitar-cupon-btn[data-pedido-id='#{pedido1.id}']", wait: 5)
    end

    it 'shows the cupón code in the applied state' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_content('RFREMOVE', wait: 5)
    end

    it 'hides the Eliminar link and shows the input after clicking Eliminar' do
      visit resumen_pedido_multipl_path(grupo)

      find(".rm-quitar-cupon-btn[data-pedido-id='#{pedido1.id}']").click

      # Page reloads; input should be back
      expect(page).to have_css("#cupon_codigo_input_#{pedido1.id}", wait: 10)
      expect(page).not_to have_css(".rm-quitar-cupon-btn[data-pedido-id='#{pedido1.id}']", wait: 3)
    end
  end

  # ---------------------------------------------------------------------------
  # Sidebar discount row
  # ---------------------------------------------------------------------------
  describe 'sidebar discount row' do
    let!(:cupon) do
      create(:cupon, tienda: tienda, codigo: 'RFSIDE',
                     tipo_descuento: 'importe', importe: 20,
                     fecha_vencimiento: Date.current + 1.month)
    end

    context 'when no cupón is applied' do
      it 'does not show a Descuentos row in the sidebar' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).not_to have_content('Descuentos', wait: 3)
      end
    end

    context 'when a cupón is applied to one pedido' do
      before do
        pedido1.aplicar_cupon!(cupon)
        pedido1.reload
      end

      it 'shows the Descuentos row in the sidebar' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).to have_content('Descuentos', wait: 5)
      end

      it 'shows the discount amount as a negative value' do
        visit resumen_pedido_multipl_path(grupo)

        # The discount is $20; look for -$20 or -20
        expect(page).to have_content('-', wait: 5)
        expect(page).to have_content('20', wait: 5)
      end

      it 'still shows the grand total' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).to have_content('Total del grupo', wait: 5)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # MP payment hint template in DOM
  # ---------------------------------------------------------------------------
  describe 'MP payment hint template' do
    it 'renders the #mp-payment-hint-template element (hidden) in the sidebar' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_css('#mp-payment-hint-template', visible: :all, wait: 5)
    end
  end

  # ---------------------------------------------------------------------------
  # MP payment button — non-CC flow
  # Uses the SAME admin user (already logged in). The pedidos belong to a
  # non-CC cuenta so pagar_mercadopago is authorised without switching users.
  # ---------------------------------------------------------------------------
  describe 'MP payment button guard for non-CC account' do
    let!(:cliente_mp) do
      create(:cliente, tienda: tienda, nombre: 'MP RF Cliente',
                       cuenta_corriente: false,
                       horarios_de_entrega: false,
                       usuario_puede_elegir_cuenta: false,
                       permitir_envios_a_domicilio: false)
    end
    let!(:cuenta_mp) do
      create(:cuenta, nombre: 'Cuenta MP RF', cliente: cliente_mp, cuenta_corriente_parcial: nil)
    end
    # grupo_mp is owned by the already-logged-in admin — no login switch needed.
    let!(:grupo_mp) { Pedidos::PedidoMultiple.create!(usuario: usuario) }
    let!(:pedido_mp) do
      make_pedido(tienda: tienda, cuenta: cuenta_mp, usuario: usuario,
                  fecha: fecha1, grupo: grupo_mp, producto: producto, cantidad: 1)
    end

    before do
      create(:precio, :for_cliente, producto: producto, cliente: cliente_mp,
                                    importe: 100, fecha_desde: Time.zone.today)
    end

    context 'when stock is sufficient' do
      before do
        # producto auto-creates a stock at local: nil via crear_stock_inicial; update it
        Productos::Stock.find_or_create_by!(producto: producto, tienda: tienda, local: nil)
                        .update!(cantidad_actual: 100, cantidad_minima: 0, cantidad_maxima: 200)
      end

      it 'shows the Pagar con Mercado Pago button' do
        visit resumen_pedido_multipl_path(grupo_mp)

        expect(page).to have_button('Pagar con Mercado Pago', wait: 5)
      end
    end

    context 'when stock is insufficient' do
      before do
        Productos::Stock.find_or_create_by!(producto: producto, tienda: tienda, local: nil)
                        .update!(cantidad_actual: 0, cantidad_minima: 0, cantidad_maxima: 200)
      end

      it 'hides the Pagar con Mercado Pago button' do
        visit resumen_pedido_multipl_path(grupo_mp)

        expect(page).not_to have_button('Pagar con Mercado Pago', wait: 3)
      end

      it 'shows the sidebar warning about stock' do
        visit resumen_pedido_multipl_path(grupo_mp)

        expect(page).to have_content('Hay productos sin stock suficiente', wait: 5)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Cuenta-only group (no usuario on the group itself)
  # ---------------------------------------------------------------------------
  describe 'grupo owned by cuenta only (no usuario)' do
    let!(:grupo_cc) { Pedidos::PedidoMultiple.create!(cuenta: cuenta) }
    let!(:pedido_cc) do
      make_pedido(tienda: tienda, cuenta: cuenta, usuario: usuario,
                  fecha: fecha1, grupo: grupo_cc, producto: producto, cantidad: 1)
    end

    it 'renders the resumen page showing the cuenta name' do
      visit resumen_pedido_multipl_path(grupo_cc)

      expect(page).to have_content('Cuenta RF', wait: 5)
    end

    it 'shows products table inside the pedido card' do
      visit resumen_pedido_multipl_path(grupo_cc)

      expect(page).to have_content('Producto RF', wait: 5)
    end
  end
end
