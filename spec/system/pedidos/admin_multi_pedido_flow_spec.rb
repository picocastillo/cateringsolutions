# frozen_string_literal: true

require 'rails_helper'

# Covers: Admin user creating grouped (multi-day) pedidos for a cliente.
#
# Flows tested:
#   1. Admin changes fecha on a pedido-with-products → sibling created, redirect to new sibling
#   2. Original pedido retains its products after sibling creation
#   3. Badge strip appears on sibling pedido showing both days
#   4. Admin navigates to resumen via "Ver grupo & Pagar" button
#   5. Resumen page shows both pedidos for admin

RSpec.describe 'Admin — multi-day pedido (pedido múltiple) flow', :js, type: :system do
  let!(:tienda) do
    create(:tienda,
           nombre: 'Admin Multi Store',
           dominio: 'localhost',
           carrito_de_compras: true,
           maneja_stock: false,
           horarios_de_entrega: false)
  end

  let!(:admin) do
    create(:usuario, :admin, :with_password,
           login: 'admin_multi_user',
           nombre: 'Admin Multi',
           email: 'adminmulti@test.com',
           visualizando_tienda: tienda).tap do |u|
      u.tiendas << tienda unless u.tiendas.include?(tienda)
    end
  end

  let!(:cliente) do
    create(:cliente,
           nombre: 'Multi Admin Cliente',
           tienda: tienda,
           dia_inicio_ciclo_facturacion: 1,
           vencimiento_a: 30,
           horarios_de_entrega: false,
           usuario_puede_elegir_cuenta: false,
           permitir_envios_a_domicilio: false,
           cuenta_corriente: true,
           listas_de_precio_privada: false)
  end

  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta Multi Admin', cliente: cliente, cuenta_corriente_parcial: true) }

  let!(:usuario_cliente) do
    create(:usuario, :cliente,
           login: 'cliente_multi_admin',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Cliente Multi Admin',
           email: 'clientemultiadmin@test.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:categoria) do
    create(:categoria, nombre: 'Cat Multi Admin', tienda: tienda, stock_activo: false, menu_diario: false)
  end

  let!(:producto) { create(:producto, nombre: 'Torta Admin', tienda: tienda, categoria: categoria) }

  let(:fecha_base) do
    d = Date.current + 1.day
    d += 1.day while d.saturday? || d.sunday?
    d
  end

  let(:fecha2) do
    d = fecha_base + 1.day
    d += 1.day while d.saturday? || d.sunday?
    d
  end

  let!(:pedido) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, usuario: usuario_cliente,
                       estado_id: 1, fecha: fecha_base, autor: admin)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    create(:producto_solicitado, pedido: p, producto: producto, cantidad: 2, precio_unitario: 150.0)
    p
  end

  before do
    create(:categoria, nombre: 'Menu Dummy Multi', tienda: tienda, menu_diario: true)
    cliente.categorias << categoria
    create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 150, fecha_desde: Time.zone.today)
    driven_by :selenium_remote

    # Log in as admin
    visit root_path
    fill_in 'username', with: 'admin_multi_user'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    page.assert_current_path('/inicio', wait: 10, ignore_query: true)
  end

  # ─── 1. Changing fecha creates a sibling pedido ────────────────────────────

  describe 'changing fecha on a pedido-with-products' do
    it 'creates a sibling and redirects to the sibling edit page' do
      visit edit_pedido_path(pedido)
      expect(page).to have_css('#carga-pedidos', wait: 15)

      page.execute_script(
        "$.onmount(); $('#pedido_fecha').val('#{fecha2.strftime('%d/%m/%Y')}').trigger('change')"
      )

      # Redirected to a DIFFERENT pedido's edit page
      expect(page).to have_current_path(%r{/pedidos/(?!#{pedido.id}/edit)\d+/edit}, wait: 15)

      # A PedidoMultiple group was created and the original is linked
      expect(pedido.reload.pedido_multiple_id).not_to be_nil
    end
  end

  # ─── 2. Original pedido retains products ───────────────────────────────────

  describe 'original pedido after group creation' do
    it 'still has its productos_solicitados' do
      visit edit_pedido_path(pedido)
      expect(page).to have_css('#carga-pedidos', wait: 15)

      page.execute_script(
        "$.onmount(); $('#pedido_fecha').val('#{fecha2.strftime('%d/%m/%Y')}').trigger('change')"
      )

      expect(page).to have_current_path(%r{/pedidos/(?!#{pedido.id}/edit)\d+/edit}, wait: 15)

      # Original pedido still has its PS
      expect(pedido.productos_solicitados.reload.count).to eq(1)
      expect(pedido.productos_solicitados.first.cantidad).to eq(2)
    end
  end

  # ─── 3. Badge strip appears on sibling ─────────────────────────────────────

  describe 'badge strip on the sibling pedido' do
    it 'shows a date badge for each pedido in the group' do
      visit edit_pedido_path(pedido)
      expect(page).to have_css('#carga-pedidos', wait: 15)

      page.execute_script(
        "$.onmount(); $('#pedido_fecha').val('#{fecha2.strftime('%d/%m/%Y')}').trigger('change')"
      )

      expect(page).to have_current_path(%r{/pedidos/(?!#{pedido.id}/edit)\d+/edit}, wait: 15)
      # Badge strip (gbs-tabs) shows at least 2 tabs (one per pedido in group)
      expect(page).to have_css('.gbs-tab', minimum: 2, wait: 10)
    end
  end

  # ─── 4. "Ver grupo & Pagar" navigates to resumen ───────────────────────────

  describe '"Ver grupo & Pagar" button' do
    it 'navigates to the resumen page' do
      # Pre-build the group so the sibling already exists
      grupo = Pedidos::PedidoMultiple.create!(usuario: admin, cuenta: cuenta)
      pedido.update_column(:pedido_multiple_id, grupo.id)
      sibling = build(:pedido, tienda: tienda, cuenta: cuenta, usuario: usuario_cliente,
                               estado_id: 1, fecha: fecha2, autor: admin,
                               pedido_multiple_id: grupo.id)
      sibling.asignar_cuenta_manual
      sibling.cuenta = cuenta
      sibling.save!

      visit edit_pedido_path(pedido)
      expect(page).to have_css('.boton-aceptar-pedido, a.confirmar', wait: 10)
      # When in a group with >1 pedido, the button text changes to "Ver grupo & Pagar"
      expect(page).to have_content(/Ver grupo.*Pagar|grupo/i, wait: 10)

      find('a.boton-aceptar-pedido, a.confirmar', match: :first).click
      expect(page).to have_current_path(resumen_pedido_multipl_path(grupo), wait: 10)
    end
  end

  # ─── 5. Resumen shows both pedidos for admin ───────────────────────────────

  describe 'resumen page for admin-owned group' do
    it 'lists both pedidos with their dates' do
      grupo = Pedidos::PedidoMultiple.create!(usuario: admin, cuenta: cuenta)
      pedido.update_column(:pedido_multiple_id, grupo.id)
      sibling = build(:pedido, tienda: tienda, cuenta: cuenta, usuario: usuario_cliente,
                               estado_id: 1, fecha: fecha2, autor: admin,
                               pedido_multiple_id: grupo.id)
      sibling.asignar_cuenta_manual
      sibling.cuenta = cuenta
      sibling.save!
      create(:producto_solicitado, pedido: sibling, producto: producto, cantidad: 1,
                                   precio_unitario: 150.0)

      visit resumen_pedido_multipl_path(grupo)

      expect(page).to have_content(I18n.l(fecha_base, format: :long).squish, wait: 10)
      expect(page).to have_content(I18n.l(fecha2, format: :long).squish)
    end
  end
end
