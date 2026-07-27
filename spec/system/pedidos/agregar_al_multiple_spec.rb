# frozen_string_literal: true

require 'rails_helper'

# Covers: the multi-day sibling creation flow triggered by changing #pedido_fecha
# when the pedido already has products.
#
# When a pedido has products and the user picks a NEW date via the datepicker:
#   1. The cambiar_cuenta AJAX handler on the server detects the fecha change
#   2. It creates (or joins) a PedidoMultiple group and a new empty sibling pedido
#   3. The JS response navigates the browser to edit the new sibling
#   4. The original pedido keeps its products intact
#
# NOTE: There is no explicit "+ Otro Día" button in the HTML.
# The route POST /pedidos/:id/agregar_al_multiple is triggered indirectly via
# the cambiar_cuenta AJAX call when fecha changes on a pedido with products.
# See pedidos_multiples_spec.rb for additional group-management flows.
RSpec.describe 'Agregar al múltiple — fecha change creates sibling', :js, type: :system do
  let!(:tienda) do
    create(:tienda,
           nombre: 'Multiple Btn Store',
           dominio: 'localhost',
           carrito_de_compras: true,
           horarios_de_entrega: false,
           maneja_stock: false)
  end

  let!(:cliente) do
    create(:cliente,
           nombre: 'Cliente Multiple Btn',
           tienda: tienda,
           dia_inicio_ciclo_facturacion: 1,
           vencimiento_a: 30,
           horarios_de_entrega: false,
           usuario_puede_elegir_cuenta: false,
           permitir_envios_a_domicilio: false,
           cuenta_corriente: true,
           listas_de_precio_privada: false)
  end

  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta Multiple Btn', cliente: cliente) }

  let!(:usuario) do
    create(:usuario, :cliente,
           login: 'multibtnuser',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Multi Btn User',
           email: 'multibtn@example.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:categoria) do
    create(:categoria, nombre: 'Cat Multi Btn', tienda: tienda, stock_activo: false, menu_diario: false)
  end

  let!(:producto) { create(:producto, nombre: 'Empanada Multiple', tienda: tienda, categoria: categoria) }

  let(:fecha1) do
    d = cuenta.proximo_dia_pedido
    d += 1.day while d.saturday? || d.sunday?
    d
  end

  let(:fecha2) do
    d = fecha1 + 1.day
    d += 1.day while d.saturday? || d.sunday?
    d
  end

  let!(:pedido) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: fecha1, autor: usuario, usuario: usuario)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    create(:producto_solicitado, pedido: p, producto: producto, cantidad: 2, precio_unitario: 150.0)
    p
  end

  before do
    create(:categoria, nombre: 'Menu Dummy', tienda: tienda, menu_diario: true)
    cliente.categorias << categoria
    create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 150,
                                  fecha_desde: Time.zone.today)

    visit root_path
    fill_in 'username', with: 'multibtnuser'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    page.assert_no_current_path('/', wait: 10)
  end

  it 'changing fecha on a pedido with products creates a sibling and redirects to edit it' do
    visit edit_pedido_path(pedido)
    expect(page).to have_css('#carga-pedidos', wait: 15)

    # Trigger fecha change via JS (the datepicker sets the value and fires 'change',
    # which POSTs to cambiar_cuenta; the server detects the fecha change on a pedido
    # with products and creates a sibling via the agregar_al_multiple logic,
    # then the JS response navigates to the new sibling's edit page).
    page.execute_script(
      "$.onmount(); $('#pedido_fecha').val('#{fecha2.strftime('%d/%m/%Y')}').trigger('change')"
    )

    # Should redirect to a NEW (different) pedido edit page
    expect(page).to have_current_path(%r{/pedidos/(?!#{pedido.id}/edit)\d+/edit}, wait: 15)

    pedido.reload
    expect(pedido.en_grupo?).to be(true)
    grupo = pedido.pedido_multiple

    # Two pedidos in the group: original (fecha1) + new sibling (fecha2)
    expect(grupo.pedidos.count).to eq(2)
    expect(grupo.pedidos.where(fecha: fecha2).count).to eq(1)

    # The original pedido still has its products
    expect(pedido.productos_solicitados.count).to eq(1)

    # The sibling is empty (no products yet)
    hermano = grupo.pedidos.where.not(id: pedido.id).first
    expect(hermano).to be_present
    expect(hermano.productos_solicitados.count).to eq(0)
  end

  it 'original pedido retains all products after sibling is created' do
    initial_count = pedido.productos_solicitados.count

    visit edit_pedido_path(pedido)
    expect(page).to have_css('#carga-pedidos', wait: 15)

    page.execute_script(
      "$.onmount(); $('#pedido_fecha').val('#{fecha2.strftime('%d/%m/%Y')}').trigger('change')"
    )
    expect(page).to have_current_path(%r{/pedidos/\d+/edit}, wait: 15)

    expect(pedido.reload.productos_solicitados.count).to eq(initial_count),
                                                         'Original pedido lost its products after fecha-change-triggered sibling creation'
  end

  it 'badge strip appears on the sibling edit page after sibling is created' do
    visit edit_pedido_path(pedido)
    expect(page).to have_css('#carga-pedidos', wait: 15)

    page.execute_script(
      "$.onmount(); $('#pedido_fecha').val('#{fecha2.strftime('%d/%m/%Y')}').trigger('change')"
    )
    expect(page).to have_current_path(%r{/pedidos/\d+/edit}, wait: 15)

    # Group badges should appear on the new sibling's edit page
    expect(page).to have_css('#grupo-badges-container', wait: 5)
    expect(page).to have_css('.gbs-wrap, .gbs-tab', wait: 5)
  end
end
