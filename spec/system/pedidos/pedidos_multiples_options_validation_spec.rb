# frozen_string_literal: true

require 'rails_helper'

# System specs covering the per-pedido option pickers + validation parity
# between single (/comprar) and múltiple (/resumen) checkout flows.
#
# Specifically asserts:
#   - Per-pedido horario selector rendering (HE=Y on cliente AND tienda)
#   - finalizar_multiple validates enviar_a_id (EC=Y, usuario_puede_elegir_cuenta)
#   - generar_pago_ml_multiple validates BEFORE creating MP preference,
#     disables the MP button + shows per-pedido hint + group summary alert
#   - generar_pago_ml_multiple uses autoOpen:true (single click) when valid
#   - "Aplicar a todos" copy-to-all buttons appear/hide correctly and propagate
#     selected values to sibling pedidos via PATCH then reload
RSpec.describe 'PedidosMultiples — Options pickers & validation parity', :js, type: :system do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def next_weekday(from = Date.current + 1.day)
    from += 1.day while from.saturday? || from.sunday?
    from
  end

  def make_pedido(fecha:, grupo:, cuenta_for_pedido: nil)
    target_cuenta = cuenta_for_pedido || cuenta
    p = build(:pedido, tienda: tienda, cuenta: target_cuenta, estado_id: 1,
                       fecha: fecha, autor: usuario, usuario: usuario,
                       pedido_multiple_id: grupo.id)
    p.asignar_cuenta_manual
    p.cuenta = target_cuenta
    p.save!
    ps = Productos::ProductoSolicitado.new(
      pedido: p, producto: producto, cantidad: 1, precio_unitario: 100.0
    )
    ps.save(validate: false)
    p
  end

  # ---------------------------------------------------------------------------
  # Shared base setup (CC-flow tienda with carrito_de_compras=true)
  # ---------------------------------------------------------------------------
  let!(:tienda) do
    create(:tienda, nombre: 'OptsValidation', dominio: 'localhost',
                    carrito_de_compras: true, maneja_stock: false,
                    horarios_de_entrega: true)
  end
  let!(:local) do
    create(:local, tienda: tienda, nombre: 'Local OV', domicilio: 'Calle OV 1', telefono: '111')
  end
  let!(:cliente) do
    create(:cliente, tienda: tienda, nombre: 'OV Cliente',
                     cuenta_corriente: true,
                     horarios_de_entrega: false,
                     usuario_puede_elegir_cuenta: false,
                     permitir_envios_a_domicilio: false)
  end
  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta OV', cliente: cliente, cuenta_corriente_parcial: true) }
  let!(:usuario) do
    create(:usuario, :admin, login: 'ov_user', password: 'password123',
                             password_confirmation: 'password123',
                             nombre: 'OV User', email: 'ov@test.com',
                             cuenta: cuenta, tienda_cliente: tienda,
                             visualizando_tienda: tienda).tap do |u|
      u.tiendas << tienda unless u.tiendas.include?(tienda)
    end
  end
  let!(:categoria) { create(:categoria, nombre: 'OV Cat', tienda: tienda, stock_activo: false) }
  let!(:producto)  { create(:producto, nombre: 'Producto OV', tienda: tienda, categoria: categoria) }

  let(:fecha1) { next_weekday }
  let(:fecha2) { next_weekday(fecha1 + 1.day) }
  let(:fecha3) { next_weekday(fecha2 + 1.day) }

  let!(:grupo)   { Pedidos::PedidoMultiple.create!(usuario: usuario, cuenta: cuenta) }
  let!(:pedido1) { make_pedido(fecha: fecha1, grupo: grupo) }
  let!(:pedido2) { make_pedido(fecha: fecha2, grupo: grupo) }

  before do
    create(:precio, :for_cliente, producto: producto, cliente: cliente,
                                  importe: 100, fecha_desde: Time.zone.today)
    allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante).and_return(true)
    driven_by :selenium_remote
    cliente_login(usuario)
  end

  # ===========================================================================
  # 1) Per-pedido HORARIO selector (HE=Y on both tienda and cliente)
  # ===========================================================================
  describe 'per-pedido horario selector (cliente HE=Y, tienda HE=Y)' do
    let!(:horario_manana) { Pedidos::Horario.create!(nombre: '9:00 - 12:00', horario: '9:00 - 12:00', tienda: tienda) }
    let!(:horario_tarde)  { Pedidos::Horario.create!(nombre: '14:00 - 17:00', horario: '14:00 - 17:00', tienda: tienda) }

    before do
      # The shared cuenta has cuenta_corriente_parcial: true (CC enabled).
      # The shared tienda already has horarios_de_entrega: true.
      # Only client HE needs enabling; the view gates horario with
      # cuenta_corriente_habilitada? + both HE flags.
      cliente.update_columns(horarios_de_entrega: true)
    end

    it 'renders one horario selector per pendiente pedido with all active options' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_css("#horario_selector_#{pedido1.id}", visible: false, wait: 5)
      expect(page).to have_css("#horario_selector_#{pedido2.id}", visible: false)

      options = page.all("#horario_selector_#{pedido1.id} option").map(&:text)
      expect(options).to include('9:00 - 12:00', '14:00 - 17:00')
    end

    context 'when cliente has horarios_de_entrega disabled' do
      before { cliente.update_columns(horarios_de_entrega: false) }

      it 'does not render the horario selector' do
        visit resumen_pedido_multipl_path(grupo)
        expect(page).to have_content(I18n.l(fecha1, format: :long).squish, wait: 5)
        expect(page).not_to have_css("#horario_selector_#{pedido1.id}", visible: false)
      end
    end

    context 'when tienda has horarios_de_entrega disabled' do
      before { tienda.update_columns(horarios_de_entrega: false) }

      it 'does not render the horario selector' do
        visit resumen_pedido_multipl_path(grupo)
        expect(page).to have_content(I18n.l(fecha1, format: :long).squish, wait: 5)
        expect(page).not_to have_css("#horario_selector_#{pedido1.id}", visible: false)
      end
    end

    it 'PATCHes the pedido and reloads when the horario is changed' do
      visit resumen_pedido_multipl_path(grupo)
      expect(page).to have_css("#horario_selector_#{pedido1.id}", visible: false, wait: 5)
      # No copy-to-all yet (horario_id is blank on both pedidos)
      expect(page).not_to have_css(%(.rm-copy-to-all[data-field="horario_id"]))

      page.execute_script(<<~JS)
        (function() {
          if (window.jQuery && typeof $.onmount === 'function') { $.onmount(); }
          var $sel = jQuery('#horario_selector_#{pedido1.id}');
          $sel.val('#{horario_manana.id}').trigger('change');
        })();
      JS

      # After PATCH success + reload, the copy-to-all button for horario_id
      # appears (rendered only when @pedidos.size > 1 && pedido.horario_id.present?)
      expect(page).to have_css(
        %(.rm-copy-to-all[data-pedido-id="#{pedido1.id}"][data-field="horario_id"]),
        wait: 15
      )
      expect(pedido1.reload.horario_id).to eq(horario_manana.id)
    end
  end

  # ===========================================================================
  # 2) finalizar_multiple — enviar_a_id renders selector when EC=Y
  # ===========================================================================
  # NOTE: enviar_a_id can never go blank from the UI because the getter falls
  # back to `cuenta.id`. The validation in finalizar_multiple defends against
  # the no-cuenta edge case (programmer error). So here we just verify that
  # the per-pedido enviar_a selector renders correctly when EC=Y, mirroring
  # what opciones_checkout_spec.rb does for the single-flow `/comprar` page.
  describe 'finalizar_multiple — enviar_a_id selector (EC=Y)' do
    let!(:cuenta_envio_b) { create(:cuenta, nombre: 'Cuenta Envío B', cliente: cliente, cuenta_corriente_parcial: true) }

    before do
      cliente.update_columns(usuario_puede_elegir_cuenta: true)
      [pedido1, pedido2].each(&:reload)
    end

    it 'renders the per-pedido enviar_a selector with all available cuentas' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_css("#enviar_a_selector_#{pedido1.id}", visible: false, wait: 5)
      options = page.all("#enviar_a_selector_#{pedido1.id} option").map(&:text)
      expect(options.any? { |o| o.include?('Cuenta OV') }).to be true
      expect(options.any? { |o| o.include?('Cuenta Envío B') }).to be true
    end

    it 'finalizar succeeds for happy path with valid enviar_a' do
      visit resumen_pedido_multipl_path(grupo)
      expect(page).to have_button('Finalizar todos', wait: 5)

      accept_confirm { click_button('Finalizar todos') }

      expect(page).to have_current_path(pedidos_path, wait: 15)
    end
  end

  # ===========================================================================
  # 3) generar_pago_ml_multiple — validation blocks MP preference creation
  # ===========================================================================
  describe 'generar_pago_ml_multiple — validation blocks MP preference' do
    # Two turnos so neither auto-assigns (single-turno triggers auto-assign JS)
    let!(:turno_a) { create(:turno_entrega, :desayuno) }
    let!(:turno_b) { create(:turno_entrega, :almuerzo) }

    before do
      # MP flow requires non-CC cuenta. Force MP path.
      cuenta.update_columns(cuenta_corriente_parcial: false)
      cliente.update_columns(cuenta_corriente: false)
      create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_a)
      create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_b)
      [pedido1, pedido2].each(&:reload)
    end

    it 'disables the MP button and shows per-pedido + summary hints when turno is missing' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_button('Pagar con Mercado Pago', wait: 5)

      click_button('Pagar con Mercado Pago')

      # Server should NOT create MP preference; instead JS response disables button + shows hints
      expect(page).to have_css('.mercadopago-button-disabled', wait: 15)
      expect(page).to have_css('#mp-multiple-validation-summary', wait: 5)
      expect(page).to have_css("#mp-payment-validation-hint-#{pedido1.id}", visible: true, wait: 5)
      expect(page).to have_css("#mp-payment-validation-hint-#{pedido2.id}", visible: true)

      # Pedido must still be pendiente (no transition happened)
      expect(pedido1.reload.estado_id).to eq(1)
      expect(pedido2.reload.estado_id).to eq(1)
    end

    it 'triggers autoOpen checkout (no second button needed) when all pedidos are valid' do
      [pedido1, pedido2].each { |p| p.update_columns(turno_entrega_id: turno_a.id) }

      visit resumen_pedido_multipl_path(grupo)
      expect(page).to have_button('Pagar con Mercado Pago', wait: 5)

      click_button('Pagar con Mercado Pago')

      # MP boton container should appear (rendered from _mercado_button partial)
      # autoOpen:true — the modal opens immediately, no second button rendered
      expect(page).to have_css('#mp-boton-container', wait: 15)
      expect(page).not_to have_css('.mercadopago-button-disabled')
      expect(page).not_to have_css('#mp-multiple-validation-summary')
      # Confirm the autoOpen path was taken (flag set before MercadoPago instantiation)
      expect(page.evaluate_script('window.mpCheckoutAutoOpened === true')).to be true
    end
  end

  # ===========================================================================
  # 4) "Aplicar a todos" copy-to-all buttons — visibility + propagation
  # ===========================================================================
  describe '"Aplicar a todos" copy-to-all buttons' do
    let!(:turno_a) { create(:turno_entrega, :desayuno) }
    let!(:turno_b) { create(:turno_entrega, :almuerzo) }

    before do
      create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_a)
      create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_b)
    end

    context 'when group has ≥2 pedidos AND a value is selected on the source' do
      before do
        pedido1.update_columns(turno_entrega_id: turno_a.id)
        pedido2.reload
      end

      it 'shows the copy-to-all button next to the source turno selector' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).to have_css(
          %(.rm-copy-to-all[data-pedido-id="#{pedido1.id}"][data-field="turno_entrega_id"]),
          wait: 5
        )
      end

      it 'does NOT show the copy-to-all button on the sibling that has no turno set' do
        visit resumen_pedido_multipl_path(grupo)

        expect(page).to have_css(
          %(.rm-copy-to-all[data-pedido-id="#{pedido1.id}"][data-field="turno_entrega_id"]),
          wait: 5
        )
        expect(page).not_to have_css(
          %(.rm-copy-to-all[data-pedido-id="#{pedido2.id}"][data-field="turno_entrega_id"])
        )
      end

      it 'PATCHes the value to all sibling pedidos and reloads after confirm' do
        visit resumen_pedido_multipl_path(grupo)
        expect(page).to have_css(%(.rm-copy-to-all[data-pedido-id="#{pedido1.id}"]), wait: 5)

        accept_confirm do
          page.execute_script(<<~JS)
            (function() {
              if (window.jQuery && typeof $.onmount === 'function') { $.onmount(); }
              jQuery('.rm-copy-to-all[data-pedido-id="#{pedido1.id}"][data-field="turno_entrega_id"]').first().trigger('click');
            })();
          JS
        end

        # Wait for reload to complete + verify DB
        expect(page).to have_content(I18n.l(fecha1, format: :long).squish, wait: 15)
        expect(pedido1.reload.turno_entrega_id).to eq(turno_a.id)
        expect(pedido2.reload.turno_entrega_id).to eq(turno_a.id)
      end
    end

    context 'when group has only 1 pedido' do
      let!(:solo_grupo)  { Pedidos::PedidoMultiple.create!(usuario: usuario, cuenta: cuenta) }
      let!(:solo_pedido) { make_pedido(fecha: fecha3, grupo: solo_grupo) }

      before { solo_pedido.update_columns(turno_entrega_id: turno_a.id) }

      it 'does NOT show any copy-to-all button (no siblings to copy to)' do
        visit resumen_pedido_multipl_path(solo_grupo)
        expect(page).to have_content(I18n.l(fecha3, format: :long).squish, wait: 5)
        expect(page).not_to have_css('.rm-copy-to-all')
      end
    end
  end
end
