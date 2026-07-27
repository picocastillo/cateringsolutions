# frozen_string_literal: true

require 'rails_helper'

# System specs for deleting (×) a sibling pedido from a PedidoMultiple group.
#
# Bug (before fix): clicking the × (gbs-remove) button on a sibling pedido raised
# an "Operación no válida" CanCan::AccessDenied error for both admin and cliente
# users. Root cause: the salir_del_multiple redirect renders the navbar which
# calls can?(:pagar_mercadopago, @pedido_pendiente). When @pedido_pendiente.cuenta
# was nil the CanCan block crashed with:
#   `undefined method 'cuenta_corriente_habilitada?' for nil`
# CanCan swallowed the NoMethodError as AccessDenied.
#
# Fix: added nil guards in pedidos/authorization.rb:
#   :aceptar         → x.cuenta&.cuenta_corriente_habilitada?
#   :pagar_mercadopago → x.cuenta.present? && !x.cuenta.cuenta_corriente_habilitada?
RSpec.describe 'PedidosMultiples — Delete sibling (×) from group', :js, type: :system do
  # ── Shared dates ────────────────────────────────────────────────────────────
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

  let(:fecha3) do
    d = fecha2 + 1.day
    d += 1.day while d.saturday? || d.sunday?
    d
  end

  # ============================================================================
  # Context: Admin user
  # Admin creates a group of 3 pedidos for a cuenta (no usuario on the pedidos,
  # which is the actual admin workflow). Tests that the × button works without
  # any authorization error.
  # ============================================================================
  context 'as admin user' do
    let!(:tienda) do
      create(:tienda,
             nombre: 'DS Admin Tienda',
             dominio: 'localhost',
             carrito_de_compras: true,
             maneja_stock: false,
             horarios_de_entrega: false)
    end
    let!(:pedido1) { make_admin_pedido(fecha: fecha1) }
    let!(:pedido2) { make_admin_pedido(fecha: fecha2) }
    let!(:pedido3) { make_admin_pedido(fecha: fecha3) }

    let!(:admin) do
      create(:usuario, :admin, :with_password,
             login: 'ds_admin_user',
             nombre: 'DS Admin',
             email: 'ds_admin_user@example.com',
             visualizando_tienda: tienda).tap { |u| u.tiendas << tienda unless u.tiendas.include?(tienda) }
    end

    let!(:cliente) do
      create(:cliente,
             tienda: tienda,
             nombre: 'DS Cliente Admin',
             cuenta_corriente: true,
             horarios_de_entrega: false,
             usuario_puede_elegir_cuenta: false,
             permitir_envios_a_domicilio: false)
    end

    let!(:cuenta) do
      create(:cuenta, nombre: 'DS Cuenta Admin', cliente: cliente,
                      cuenta_corriente_parcial: true)
    end

    let!(:categoria) { create(:categoria, nombre: 'DS Cat Admin', tienda: tienda, stock_activo: false) }
    let!(:producto)  { create(:producto, nombre: 'DS Prod Admin', tienda: tienda, categoria: categoria) }

    let!(:grupo) { Pedidos::PedidoMultiple.create!(cuenta: cuenta) }

    def make_admin_pedido(fecha:)
      p = Pedidos::Pedido.new(
        tienda: tienda, cuenta: cuenta,
        estado_id: 1, fecha: fecha,
        autor: admin, usuario: nil,
        pedido_multiple_id: grupo.id,
        pedido_para_empresa: false
      )
      p.save(validate: false)
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
      admin_login(admin)
    end

    it 'deletes a sibling pedido without authorization error and shows 2 remaining tabs' do
      visit edit_pedido_path(pedido1)
      expect(page).to have_current_path(edit_pedido_path(pedido1), wait: 5)

      # 3 group tabs should be rendered
      expect(page).to have_css('.gbs-tab', count: 3, wait: 5)

      # Click × on pedido2 (middle sibling)
      accept_confirm do
        find("a.gbs-remove[href='#{salir_del_multiple_pedido_path(pedido2)}']", wait: 5).click
      end

      # Should redirect to another pedido's edit page (pedido1 or pedido3)
      expect(page).to have_current_path(%r{/pedidos/\d+/edit}, wait: 10)

      # Must NOT show the authorization-error flash
      expect(page).not_to have_text('Operación no válida', wait: 2)
      expect(page).not_to have_text('no tiene permisos', wait: 2)

      # Only 2 tabs remain
      expect(page).to have_css('.gbs-tab', count: 2, wait: 5)
    end

    it 'deletes another sibling leaving 1 pedido and ungroups it (redirect to new)' do
      visit edit_pedido_path(pedido1)
      expect(page).to have_css('.gbs-tab', count: 3, wait: 5)

      # Delete pedido2
      accept_confirm do
        find("a.gbs-remove[href='#{salir_del_multiple_pedido_path(pedido2)}']", wait: 5).click
      end
      expect(page).to have_css('.gbs-tab', count: 2, wait: 10)

      # Now delete pedido3 — only pedido1 remains, group is dissolved
      accept_confirm do
        find("a.gbs-remove[href='#{salir_del_multiple_pedido_path(pedido3)}']", wait: 5).click
      end

      # Group gone, no authorization error, redirected
      expect(page).not_to have_text('Operación no válida', wait: 2)
      expect(page).to have_current_path(%r{/pedidos}, wait: 10)
      # No group tabs — pedido1 is now ungrouped
      expect(page).not_to have_css('.gbs-tab', wait: 2)
    end
  end

  # ============================================================================
  # Context: Cliente user
  # Cliente creates a group of 3 pedidos (with usuario set to themselves).
  # Tests that the × button works without any authorization error.
  # ============================================================================
  context 'as cliente user' do
    let!(:tienda) do
      create(:tienda,
             nombre: 'DS Cliente Tienda',
             dominio: 'localhost',
             carrito_de_compras: true,
             maneja_stock: false,
             horarios_de_entrega: false)
    end
    let!(:pedido1) { make_cliente_pedido(fecha: fecha1) }
    let!(:pedido2) { make_cliente_pedido(fecha: fecha2) }
    let!(:pedido3) { make_cliente_pedido(fecha: fecha3) }

    let!(:cliente) do
      create(:cliente,
             tienda: tienda,
             nombre: 'DS Cliente',
             cuenta_corriente: false,
             horarios_de_entrega: false,
             usuario_puede_elegir_cuenta: false,
             permitir_envios_a_domicilio: false)
    end

    let!(:cuenta) do
      create(:cuenta, nombre: 'DS Cuenta Cliente', cliente: cliente,
                      cuenta_corriente_parcial: nil)
    end

    let!(:usuario) do
      create(:usuario, :cliente, :with_password,
             login: 'ds_cliente_user',
             nombre: 'DS Cliente User',
             email: 'ds_cliente_user@example.com',
             cuenta: cuenta,
             tienda_cliente: tienda,
             visualizando_tienda: tienda)
    end

    let!(:categoria) { create(:categoria, nombre: 'DS Cat Cliente', tienda: tienda, stock_activo: false) }
    let!(:producto)  { create(:producto, nombre: 'DS Prod Cliente', tienda: tienda, categoria: categoria) }

    let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: usuario, cuenta: cuenta) }

    def make_cliente_pedido(fecha:)
      p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                         fecha: fecha, autor: usuario, usuario: usuario,
                         pedido_multiple_id: grupo.id)
      p.asignar_cuenta_manual
      p.cuenta = cuenta
      p.save!
      ps = Productos::ProductoSolicitado.new(
        pedido: p, producto: producto, cantidad: 1, precio_unitario: 80.0
      )
      ps.save(validate: false)
      p
    end

    before do
      create(:precio, :for_cliente, producto: producto, cliente: cliente,
                                    importe: 80, fecha_desde: Time.zone.today)
      allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante).and_return(true)
      driven_by :selenium_remote
      cliente_login(usuario)
      # PedidosController#new auto-enrolls a new empty pedido shell into the open group
      # when the login redirect fires. Destroy it so each test sees exactly 3 tabs.
      Pedidos::Pedido.where(pedido_multiple_id: grupo.id)
                     .where.not(id: [pedido1.id, pedido2.id, pedido3.id])
                     .delete_all
    end

    it 'cliente deletes a sibling pedido without authorization error and shows 2 remaining tabs' do
      visit edit_pedido_path(pedido1)
      expect(page).to have_current_path(edit_pedido_path(pedido1), wait: 5)

      # 3 group tabs should be rendered
      expect(page).to have_css('.gbs-tab', count: 3, wait: 5)

      # Click × on pedido2 (middle sibling)
      accept_confirm do
        find("a.gbs-remove[href='#{salir_del_multiple_pedido_path(pedido2)}']", wait: 5).click
      end

      # Should redirect to another pedido's edit page without auth error
      expect(page).to have_current_path(%r{/pedidos/\d+/edit}, wait: 10)
      expect(page).not_to have_text('Operación no válida', wait: 2)
      expect(page).not_to have_text('no tiene permisos', wait: 2)

      # Only 2 tabs remain
      expect(page).to have_css('.gbs-tab', count: 2, wait: 5)
    end

    it 'cliente deletes all siblings leaving only 1 pedido ungrouped' do
      visit edit_pedido_path(pedido1)
      expect(page).to have_css('.gbs-tab', count: 3, wait: 5)

      # Delete pedido2
      accept_confirm do
        find("a.gbs-remove[href='#{salir_del_multiple_pedido_path(pedido2)}']", wait: 5).click
      end
      expect(page).to have_css('.gbs-tab', count: 2, wait: 10)

      # Delete pedido3 — group dissolves
      accept_confirm do
        find("a.gbs-remove[href='#{salir_del_multiple_pedido_path(pedido3)}']", wait: 5).click
      end

      expect(page).not_to have_text('Operación no válida', wait: 2)
      expect(page).to have_current_path(%r{/pedidos}, wait: 10)
      expect(page).not_to have_css('.gbs-tab', wait: 2)
    end
  end
end
