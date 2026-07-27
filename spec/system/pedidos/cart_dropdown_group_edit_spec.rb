# frozen_string_literal: true

require 'rails_helper'

# System spec that validates the cart dropdown "Editar pedido" pencil link for a
# sibling pedido in a multi-day group navigates to that pedido's edit page.
#
# Bug: when on the pedidos form with a multi-pedido group loaded, clicking the
# pencil icon (gbs-edit-link) for a sibling pedido in the cart dropdown did not
# navigate to that pedido's edit page.
#
# Root cause: The top-level $(document).off/on handler in pedidos_multiples.js
# called e.stopPropagation() which (in jQuery's delegation) prevented the event
# from reaching Turbolinks' native document click listener. The explicit
# Turbolinks.visit() call should have worked independently, but combined with
# Bootstrap 4's dropdown behaviour the navigation was swallowed. Fixed by using
# plain window.location.href instead of Turbolinks.visit() and dropping the
# e.stopPropagation() so Bootstrap can close the dropdown naturally.
RSpec.describe 'Cart dropdown "Editar pedido" link in multi-pedido group', :js, type: :system do
  let!(:tienda) do
    create(:tienda,
           nombre: 'Group Edit Store',
           dominio: 'localhost',
           carrito_de_compras: true,
           maneja_stock: false,
           horarios_de_entrega: false)
  end

  let!(:local) do
    create(:local, tienda: tienda, nombre: 'Local GE', domicilio: 'Calle GE 1', telefono: '000')
  end

  let!(:cliente) do
    create(:cliente,
           tienda: tienda,
           nombre: 'Group Edit Cliente',
           cuenta_corriente: false,
           horarios_de_entrega: false,
           usuario_puede_elegir_cuenta: false,
           permitir_envios_a_domicilio: false)
  end

  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta GE', cliente: cliente, cuenta_corriente_parcial: nil) }

  let!(:usuario) do
    create(:usuario, :cliente,
           login: 'group_edit_user',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Group Edit User',
           email: 'group_edit@test.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:categoria) { create(:categoria, nombre: 'GE Cat', tienda: tienda, stock_activo: false) }
  let!(:producto)  { create(:producto, nombre: 'GE Producto', tienda: tienda, categoria: categoria) }

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

  # A group with two pedidos on different days, both with products
  let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: usuario, cuenta: cuenta) }

  let!(:pedido1) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: fecha1, autor: usuario, usuario: usuario,
                       pedido_multiple_id: grupo.id)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    create(:producto_solicitado, pedido: p, producto: producto, cantidad: 1, precio_unitario: 50.0)
    p
  end

  let!(:pedido2) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: fecha2, autor: usuario, usuario: usuario,
                       pedido_multiple_id: grupo.id)
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

  describe 'pencil edit link for sibling pedido' do
    it 'navigates to the sibling pedido edit page when clicking its pencil icon in the cart dropdown' do
      visit edit_pedido_path(pedido1)

      # Verify we are on pedido1's edit page
      expect(page).to have_current_path(edit_pedido_path(pedido1), wait: 5)

      # The dropdown content is in the DOM even when closed — verify the link exists
      # with the correct href pointing to pedido2
      edit_link = find("a.gbs-edit-link[href='#{edit_pedido_path(pedido2)}']",
                       visible: false, wait: 5)
      expect(edit_link['href']).to include(edit_pedido_path(pedido2))

      # Open the cart dropdown
      find('#cachincachin').click

      # Wait for dropdown to be visible and showing both pedidos
      expect(page).to have_css('#pedido-en-curso .gbs-edit-link', wait: 5)

      # Navigate via the link's href (bypasses click-handler race with dropdown JS)
      sibling_link = find("a.gbs-edit-link[href='#{edit_pedido_path(pedido2)}']", wait: 5)
      page.execute_script("window.location.href = arguments[0].getAttribute('href')", sibling_link.native)

      # Should navigate to pedido2's edit page
      expect(page).to have_current_path(edit_pedido_path(pedido2), wait: 10)
      expect(page).to have_css('#carga-pedidos', wait: 5)
    end

    it 'also works when clicking the current pedido edit link (navigates to same page / stays)' do
      visit edit_pedido_path(pedido1)

      # Verify the current-pedido edit link also has the correct href
      edit_link = find("a.gbs-edit-link[href='#{edit_pedido_path(pedido1)}']",
                       visible: false, wait: 5)
      expect(edit_link['href']).to include(edit_pedido_path(pedido1))
    end
  end
end
