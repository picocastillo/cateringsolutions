# frozen_string_literal: true

require 'rails_helper'

# System specs for Pedidos Múltiples: the multi-day group ordering flow.
#
# Covered flows:
#   1. The explicit "+ Otro día" button is not shown
#   2. Changing fecha after adding products creates a new sibling pedido
#   3. Badge strip appears on the sibling pedido edit page
#   4. Removing a sibling via the "−" badge button works
#   5. When group shrinks to 1, badge strip disappears and group is destroyed
#   6. "Ver grupo & Pagar" button navigates to the resumen page
#   7. Resumen page lists all pedidos with their dates and totals

RSpec.describe 'Pedidos Múltiples flow', :js, type: :system do
  # ---------------------------------------------------------------------------
  # Shared setup
  # ---------------------------------------------------------------------------
  let!(:tienda) do
    create(:tienda,
           nombre: 'Multi Pedido Store',
           dominio: 'localhost',
           carrito_de_compras: true,
           maneja_stock: false,
           horarios_de_entrega: false)
  end

  let!(:local) { create(:local, tienda: tienda, nombre: 'Local MP', domicilio: 'Calle MP 1', telefono: '000') }

  let!(:cliente) do
    create(:cliente,
           tienda: tienda,
           nombre: 'Multi Cliente',
           cuenta_corriente: false,
           horarios_de_entrega: false,
           usuario_puede_elegir_cuenta: false,
           permitir_envios_a_domicilio: false)
  end

  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta Multi', cliente: cliente) }

  let!(:usuario) do
    create(:usuario, :cliente,
           login: 'multi_user',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Multi User',
           email: 'multi@test.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:categoria) { create(:categoria, nombre: 'Multi Cat', tienda: tienda, stock_activo: false) }
  let!(:producto)  { create(:producto, nombre: 'Multi Prod', tienda: tienda, categoria: categoria) }

  # A valid future weekday date (not Sat/Sun) to avoid "no se cocina" validations
  let(:fecha_valida) do
    d = Date.current + 1.day
    d += 1.day while d.saturday? || d.sunday?
    d
  end

  # A pedido with one product already loaded (needed for fecha-change grouping)
  let!(:pedido) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: fecha_valida, autor: usuario, usuario: usuario)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    create(:producto_solicitado, pedido: p, producto: producto, cantidad: 1, precio_unitario: 50.0)
    p
  end

  before do
    create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 50, fecha_desde: Time.zone.today)
    driven_by :selenium_remote
    cliente_login(usuario)
  end

  def datepicker_date_ms(fecha)
    fecha.to_time(:utc).to_i * 1000
  end

  def abrir_datepicker
    find('#pedido_fecha').click
    expect(page).to have_css('.datepicker-days td.day[data-date]', wait: 5)
  end

  def grupo_fecha_label(fecha)
    I18n.l(fecha, format: '%a %-d %b').delete('.').titleize
  end

  # ---------------------------------------------------------------------------
  # 1. The explicit "+ Otro día" button is not shown
  # ---------------------------------------------------------------------------
  describe '"+ Otro día" button visibility' do
    it 'does not show the add-to-group button on the pedido edit page' do
      visit edit_pedido_path(pedido)

      expect(page).not_to have_css('.multi-add-btn', wait: 3)
      expect(page).not_to have_content('+ Otro día')
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Changing fecha creates a sibling when the pedido already has products
  # ---------------------------------------------------------------------------
  describe 'changing fecha to add another day' do
    let(:fecha2) do
      d = fecha_valida + 1.day
      d += 1.day while d.saturday? || d.sunday?
      d
    end

    it 'redirects to a new sibling pedido edit page when the current pedido has products' do
      visit edit_pedido_path(pedido)

      page.execute_script("$.onmount(); $('#pedido_fecha').val('#{fecha2.strftime('%d/%m/%Y')}').trigger('change')")

      # Should land on a different pedido edit page
      expect(page).to have_current_path(%r{/pedidos/(?!#{pedido.id}/edit)\d+/edit}, wait: 10)
      expect(pedido.reload.pedido_multiple).to be_present
      expect(pedido.pedido_multiple.pedidos.where(fecha: fecha2).count).to eq(1)
    end

    it 'just changes the date when the pedido has no products yet' do
      empty_pedido = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                                    fecha: fecha_valida, autor: usuario, usuario: usuario)
      empty_pedido.asignar_cuenta_manual
      empty_pedido.cuenta = cuenta
      empty_pedido.save!

      visit edit_pedido_path(empty_pedido)

      page.execute_script("$.onmount(); $('#pedido_fecha').val('#{fecha2.strftime('%d/%m/%Y')}').trigger('change')")
      page.evaluate_async_script(<<~JS)
        var done = arguments[0];
        if (jQuery.active === 0) { done(); }
        else { jQuery(document).one('ajaxStop', done); }
      JS

      expect(page).to have_current_path(edit_pedido_path(empty_pedido), wait: 10)
      expect(page).to have_css('#productos-en-venta', wait: 10)
      expect(empty_pedido.reload.fecha).to eq(fecha2)
      expect(empty_pedido.pedido_multiple_id).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Badge strip is visible on the sibling pedido edit page
  # ---------------------------------------------------------------------------
  describe 'badge strip after adding a sibling' do
    let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: usuario) }
    let!(:fecha2) do
      d = fecha_valida + 1.day
      d += 1.day while d.saturday? || d.sunday?
      d
    end
    let!(:pedido2) do
      p2 = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                          fecha: fecha2, autor: usuario, usuario: usuario,
                          pedido_multiple_id: grupo.id)
      p2.asignar_cuenta_manual
      p2.cuenta = cuenta
      p2.save!
      create(:producto_solicitado, pedido: p2, producto: producto, cantidad: 1, precio_unitario: 50.0)
      p2
    end

    before do
      pedido.update!(pedido_multiple_id: grupo.id)
    end

    it 'shows the badge strip with both pedidos' do
      visit edit_pedido_path(pedido)

      expect(page).to have_css('.gbs-wrap', wait: 5)
      expect(page).to have_css('.gbs-tab', minimum: 2)
      expect(page).to have_css('.gbs-tab__date', text: grupo_fecha_label(fecha_valida))
      expect(page).to have_css('.gbs-tab__date', text: grupo_fecha_label(fecha2))
    end

    it 'does not show a duplicate resumen link in the badge strip' do
      visit edit_pedido_path(pedido)

      expect(page).to have_css('.gbs-wrap', wait: 5)
      within('.gbs-wrap') do
        expect(page).not_to have_link('Ver resumen')
      end
    end

    it 'highlights the current pedido badge as active' do
      visit edit_pedido_path(pedido)

      expect(page).to have_css('.gbs-tab--active', wait: 5)
    end

    it 'highlights pedido group dates in the datepicker' do
      visit edit_pedido_path(pedido)

      expect(page).to have_css('.gbs-wrap', wait: 5)
      abrir_datepicker

      expect(page).to have_css(".datepicker-days td.day.pedido-group-date.pedido-current-date[data-date='#{datepicker_date_ms(fecha_valida)}']")
      expect(page).to have_css(".datepicker-days td.day.pedido-group-date[data-date='#{datepicker_date_ms(fecha2)}']")
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Removing a sibling via the badge "−" button
  # ---------------------------------------------------------------------------
  describe 'removing a sibling from the group' do
    let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: usuario) }
    let!(:fecha2) do
      d = fecha_valida + 1.day
      d += 1.day while d.saturday? || d.sunday?
      d
    end
    let!(:pedido2) do
      p2 = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                          fecha: fecha2, autor: usuario, usuario: usuario,
                          pedido_multiple_id: grupo.id)
      p2.asignar_cuenta_manual
      p2.cuenta = cuenta
      p2.save!
      create(:producto_solicitado, pedido: p2, producto: producto, cantidad: 1, precio_unitario: 50.0)
      p2
    end

    before do
      pedido.update!(pedido_multiple_id: grupo.id)
    end

    it 'removes the sibling badge and the badge strip disappears when group shrinks to 1' do
      visit edit_pedido_path(pedido)

      expect(page).to have_css('.gbs-wrap', wait: 5)
      expect(page).to have_css('.gbs-tab', minimum: 2)

      # Click the remove (−) button on the sibling (not the active one)
      # The sibling badges have a remove button; accept the confirm dialog
      page.accept_confirm do
        # Find the remove button not on the active badge
        all('.gbs-remove').reject do |el|
          el.ancestor('.gbs-tab-wrap').has_css?('.gbs-tab--active')
        end.first.click
      end

      # Group now has 1 member → strip disappears
      expect(page).not_to have_css('.gbs-wrap', wait: 10)
      expect(pedido.reload.pedido_multiple_id).to be_nil

      abrir_datepicker
      expect(page).not_to have_css('.datepicker-days td.day.pedido-group-date', wait: 5)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. "Ver grupo & Pagar" navigates to resumen page
  # ---------------------------------------------------------------------------
  describe 'Ver resumen page' do
    let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: usuario) }
    let!(:fecha2) do
      d = fecha_valida + 1.day
      d += 1.day while d.saturday? || d.sunday?
      d
    end
    let!(:pedido2) do
      p2 = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                          fecha: fecha2, autor: usuario, usuario: usuario,
                          pedido_multiple_id: grupo.id)
      p2.asignar_cuenta_manual
      p2.cuenta = cuenta
      p2.save!
      create(:producto_solicitado, pedido: p2, producto: producto, cantidad: 1, precio_unitario: 50.0)
      p2
    end

    before do
      pedido.update!(pedido_multiple_id: grupo.id)
    end

    it 'renders the resumen page with both pedidos listed' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_css('#resumen-multiple', wait: 5)
      expect(page).to have_content(I18n.l(fecha_valida, format: :long).squish)
      expect(page).to have_content(I18n.l(fecha2, format: :long).squish)
    end

    it 'shows the total del grupo' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_content('Total del grupo', wait: 5)
    end

    it 'shows Pagar con Mercado Pago button when grupo is abierto' do
      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_css('#preference-container-multiple', wait: 5)
      expect(page).to have_button('Pagar con Mercado Pago').or(have_css('input[value*="Pagar"]'))
    end

    it 'navigates to resumen via the Ver grupo & Pagar button' do
      visit edit_pedido_path(pedido)

      within('#boton-compra') do
        click_link 'Ver grupo & Pagar', wait: 5
      end

      expect(page).to have_current_path(resumen_pedido_multipl_path(grupo), wait: 10)
    end
  end
end
