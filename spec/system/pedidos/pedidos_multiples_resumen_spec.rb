require 'rails_helper'

# System specs for the PedidosMultiples RESUMEN page and finalizar_multiple flow:
#   - Resumen renders all pedidos in group
#   - Duplicate date shows amber warning
#   - Finalizar button triggers the multi-accept flow (cuenta corriente)
#   - Turno validation: missing turno shows error on resumen
#   - enviar_a_id JS: selecting "Domicilio Particular" shows direccion input
RSpec.describe 'PedidosMultiples — Resumen & Finalizar flow', :js, type: :system do
  let!(:tienda) do
    create(:tienda, nombre: 'Resumen Store', dominio: 'localhost',
                    carrito_de_compras: true, maneja_stock: false,
                    horarios_de_entrega: false)
  end
  let!(:grupo)   { Pedidos::PedidoMultiple.create!(usuario: usuario) }
  let!(:pedido1) { make_pedido(fecha: fecha1, grupo: grupo) }
  let!(:pedido2) { make_pedido(fecha: fecha2, grupo: grupo) }
  let!(:local) do
    create(:local, tienda: tienda, nombre: 'Local RS', domicilio: 'Calle RS 1', telefono: '000')
  end
  let!(:cliente) do
    create(:cliente, tienda: tienda, nombre: 'Resumen Cliente',
                     cuenta_corriente: true,
                     horarios_de_entrega: false,
                     usuario_puede_elegir_cuenta: false,
                     permitir_envios_a_domicilio: false)
  end
  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta RS', cliente: cliente, cuenta_corriente_parcial: true) }
  let!(:usuario) do
    create(:usuario, :admin, login: 'rs_user', password: 'password123',
                             password_confirmation: 'password123',
                             nombre: 'RS User', email: 'rs@test.com',
                             cuenta: cuenta, tienda_cliente: tienda,
                             visualizando_tienda: tienda).tap do |u|
      u.tiendas << tienda unless u.tiendas.include?(tienda)
    end
  end
  let!(:categoria) { create(:categoria, nombre: 'RS Cat', tienda: tienda, stock_activo: false) }
  let!(:producto) { create(:producto, nombre: 'Producto RS', tienda: tienda, categoria: categoria) }

  let(:fecha1) do
    d = Date.current + 1.day
    d += 1.day while d.saturday? || d.sunday?
    d
  end
  let(:fecha2) do
    d = fecha1 + 1.day
    d += 1.day while d.saturday? || d.sunday?
    d
  end

  def make_pedido(fecha:, grupo:)
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: fecha, autor: usuario, usuario: usuario,
                       pedido_multiple_id: grupo.id)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    ps = Productos::ProductoSolicitado.new(
      pedido: p, producto: producto, cantidad: 1, precio_unitario: 100.0
    )
    ps.save(validate: false)
    p
  end

  before do
    create(:precio, :for_cliente, producto: producto, cliente: cliente,
                                  importe: 100, fecha_desde: Time.zone.today)
    allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante).and_return(true)
    driven_by :selenium_remote
    cliente_login(usuario)
  end

  # -------------------------------------------------------------------------
  describe 'resumen page renders group summary' do
    it 'shows both pedidos with their dates' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_content(I18n.l(fecha1, format: :long).squish, wait: 5)
      expect(page).to have_content(I18n.l(fecha2, format: :long).squish)
    end

    it 'shows the group total' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_content('Total del grupo', wait: 5)
      # 2 × $100.00
      expect(page).to have_content('200')
    end

    it 'shows the Finalizar Pedidos button for cuenta corriente flow' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_button('Finalizar todos', wait: 5)
    end
  end

  # -------------------------------------------------------------------------
  describe 'duplicate date warning' do
    let!(:pedido_dup) { make_pedido(fecha: fecha1, grupo: grupo) }

    it 'shows an amber duplicate-date warning banner' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_css('.rm-dup-alert', wait: 5)
      expect(page).to have_content('Hay pedidos con la misma fecha')
    end

    it 'shows a Dup. pill on the duplicate pedido cards' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_content('Dup.', wait: 5)
    end
  end

  # -------------------------------------------------------------------------
  describe 'finalizar flow — happy path (no turno required)' do
    it 'submitting Finalizar transitions pedidos and redirects to pedidos_path' do
      visit resumen_pedido_multipl_path(grupo)

      # Find and click the Finalizar button (confirms the dialog)
      accept_confirm do
        click_button('Finalizar todos', wait: 5)
      end

      # Should arrive on pedidos list
      expect(page).to have_current_path(pedidos_path, wait: 15)
      expect(page).to have_content('finalizados correctamente', wait: 5)
    end
  end

  # -------------------------------------------------------------------------
  describe 'finalizar flow — turno validation' do
    let!(:turno)   { create(:turno_entrega, :almuerzo) }
    let!(:turno_b) { create(:turno_entrega, :desayuno) }

    before do
      create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno)
      create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_b)
    end

    it 'shows turno error and stays on resumen when turno is missing' do
      visit resumen_pedido_multipl_path(grupo)

      accept_confirm do
        click_button('Finalizar todos', wait: 5)
      end

      # Should redirect back to resumen with error
      expect(page).to have_current_path(resumen_pedido_multipl_path(grupo), wait: 15)
      expect(page).to have_content('Turno de Entrega', wait: 5)
    end
  end

  # -------------------------------------------------------------------------
  describe 'enviar_a_id field — domicilio particular shows direccion input' do
    before do
      cliente.update_columns(usuario_puede_elegir_cuenta: false, permitir_envios_a_domicilio: true)
      # Reload pedidos so opciones_de_envio includes the domicilio option
      [pedido1, pedido2].each(&:reload)
    end

    it 'shows the direccion_envio input when Domicilio Particular is selected' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_css("#enviar_a_selector_#{pedido1.id}", visible: false, wait: 5)

      # Confirm wrap starts hidden
      expect(page).not_to have_css("#direccion-envio-wrap-#{pedido1.id}")

      # Call $.onmount() first inside the same script so handler is guaranteed bound
      # before trigger fires — turbolinks:load may not have fired yet when have_css returns
      page.execute_script(<<~JS)
        (function() {
          if (window.jQuery && typeof $.onmount === 'function') { $.onmount(); }
          var $sel = jQuery('#enviar_a_selector_#{pedido1.id}');
          if (!$sel.length) return;
          $sel.val('-1').trigger('change');
        })();
      JS

      # Capybara retries until element is visible (up to default wait)
      expect(page).to have_css("#direccion-envio-wrap-#{pedido1.id}", wait: 5)
    end

    it 'hides the direccion_envio input when a regular account is selected' do
      pedido1.update_columns(envio_a_domicilio: true, direccion_envio: 'Calle Test')

      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_css("#enviar_a_selector_#{pedido1.id}", visible: false, wait: 5)
      expect(page).to have_css("#direccion-envio-wrap-#{pedido1.id}")

      select_val = pedido1.cuenta_id.to_s
      page.execute_script(<<~JS)
        (function() {
          if (window.jQuery && typeof $.onmount === 'function') { $.onmount(); }
          var $sel = jQuery('#enviar_a_selector_#{pedido1.id}');
          if (!$sel.length) return;
          $sel.val('#{select_val}').trigger('change');
        })();
      JS

      # Capybara retries until element is hidden / not visible (up to default wait)
      expect(page).not_to have_css("#direccion-envio-wrap-#{pedido1.id}", wait: 5)
    end
  end
end
