# frozen_string_literal: true

require 'rails_helper'

# REGRESSION (April 2026): a recent change to `Pedidos::Pedido#asignar_cuenta`
# added a `raise ErrorAplicacion` and a `usuario_puede_elegir_cuenta` short-circuit.
# The reporter says pedidos crash in prod when a usuario cliente picks a non-default
# cuenta (Enviar a) and clicks Finalizar Compra.
#
# This is the exact end-to-end flow the user described:
#   1. usuario cliente logs in (cuenta corriente flow → estado 2 = aceptado)
#   2. adds products to the cart
#   3. on the comprar (cart) page, picks a NON-DEFAULT cuenta in the
#      "Enviar a" dropdown (cliente has `usuario_puede_elegir_cuenta: true`
#      and there are multiple cuentas)
#   4. clicks "Finalizar Compra"
#   5. visits the pedidos index and sees the pedido in estado Aceptado
#   6. opens the pedido detail and sees the SAME alternate cuenta and
#      estado Aceptado
RSpec.describe 'Cliente picks alternate cuenta and finalizes (no crash)', :js, type: :system do
  let!(:tienda) do
    create(:tienda,
           nombre: 'Asignar Cuenta Test Tienda',
           dominio: 'localhost',
           telefono: '111222333',
           email: 'asignarcuenta@test.com',
           carrito_de_compras: true,
           horarios_de_entrega: false,
           maneja_stock: false)
  end

  let!(:cliente) do
    create(:cliente,
           tienda: tienda,
           nombre: 'Cliente Multi Cuenta CC',
           cuenta_corriente: true,
           horarios_de_entrega: false,
           usuario_puede_elegir_cuenta: true,
           permitir_envios_a_domicilio: false,
           dia_inicio_ciclo_facturacion: 1,
           vencimiento_a: 30,
           listas_de_precio_privada: false)
  end

  # Two cuentas under the same cliente. cuenta_default is the user's default;
  # cuenta_alternativa is the one the user must pick from the "Enviar a" dropdown.
  let!(:cuenta_default) do
    create(:cuenta, nombre: 'Cuenta Default', cliente: cliente, position: 1, cuenta_corriente_parcial: nil)
  end
  let!(:cuenta_alternativa) do
    create(:cuenta, nombre: 'Cuenta Alternativa', cliente: cliente, position: 2, cuenta_corriente_parcial: nil)
  end

  let!(:cliente_user) do
    create(:usuario, :cliente,
           login: 'clientemulticuentacc',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Multi Cuenta CC User',
           email: 'multicuentacc@test.com',
           cuenta: cuenta_default,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:categoria) { create(:categoria, nombre: 'Bebidas', tienda: tienda, stock_activo: false) }
  # Dummy daily menu category to avoid SQL issue (mirrors pedido_cliente_stock_flow_spec.rb)
  let!(:categoria_menu_diario) do
    create(:categoria, nombre: 'Menu Diario Dummy', tienda: tienda, menu_diario: true)
  end
  let!(:producto) do
    create(:producto, nombre: 'Agua Mineral 500ml', codigo: 'AGU001',
                      tienda: tienda, categoria: categoria, discontinued_at: nil)
  end

  before do
    # Comprobantes::Tipo records needed for the billing system (created by `crear_comprobante`
    # after-save callback that fires when the pedido transitions to estado=2 / aceptado).
    Comprobantes::Tipo.find_or_create_by(codigo: 1) do |tipo|
      tipo.desc  = 'Factura'
      tipo.clase = 'Ventas::Facturacion::Factura'
      tipo.letra = 'A'
      tipo.debitan = false
    end
    Comprobantes::Tipo.find_or_create_by(codigo: 3) do |tipo|
      tipo.desc  = 'Nota de Crédito'
      tipo.clase = 'Ventas::Facturacion::NotaCredito'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    # Associate cliente with category (mirrors existing system specs)
    cliente.categorias << categoria unless cliente.categorias.include?(categoria)
    cliente.reload

    create(:precio,
           producto: producto,
           importe: 100.0,
           fecha_desde: 1.week.ago,
           fecha_hasta: 1.year.from_now)
  end

  scenario 'usuario cliente picks alternate cuenta on comprar, finalizes, sees aceptado in index and detail' do
    # 1. Login as the cliente user
    visit root_path
    fill_in 'username', with: 'clientemulticuentacc'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'

    expect(page).to have_current_path(%r{/pedidos}, wait: 5)

    # 2. Add product to cart
    expect(page).to have_css('.producto-venta', minimum: 1)
    producto_card = page.all('.producto-venta').find { |c| c.text.include?(producto.nombre) }
    expect(producto_card).not_to be_nil

    2.times do
      within(producto_card) do
        find('a.mas').click
        sleep(0.3)
      end
    end

    # 3. Go to cart (comprar) page
    carrito_button = page.find('a, button', text: /ir al carrito/i, match: :first)
    carrito_button.click

    expect(page).to have_current_path(%r{/pedidos/\d+/comprar}, wait: 5)
    expect(page).to have_content('Finalizar Compra')

    # 4. The "Enviar a" dropdown must be visible with both cuentas listed.
    default_label    = cuenta_default.cliente_y_nombre
    alternate_label  = cuenta_alternativa.cliente_y_nombre

    expect(page).to have_select('pedido_enviar_a_id',
                                with_options: [default_label, alternate_label])

    # 5. Pick the NON-default cuenta (the one not pre-selected).
    select alternate_label, from: 'pedido_enviar_a_id'

    # 6. Click "Finalizar Compra" — this is the action reported as crashing in prod.
    #    JS injects ?enviar_a_id=<alternativa.id> into the link's href before
    #    rails-ujs submits the POST.
    pedido = Pedidos::Pedido.where(usuario_id: cliente_user.id).order(created_at: :desc).first
    expect(pedido).not_to be_nil

    click_link 'Finalizar Compra'

    # 7. After finalizar, the controller redirects to the pedido show page.
    expect(page).to have_current_path(pedido_path(pedido), wait: 10)

    # No 500 / no ErrorAplicacion bubble — sanity-check the page rendered.
    expect(page).to have_content('Pedido', wait: 5)
    expect(page).not_to have_content('ErrorAplicacion')
    expect(page).not_to have_content("doesn't exist") # generic Rails error tells

    # 8. Pedido must be persisted with estado=2 (aceptado) and cuenta=alternativa.
    pedido.reload
    expect(pedido.estado_id).to eq(2), "expected estado_id=2 (aceptado), got #{pedido.estado_id}"
    expect(pedido.cuenta_id).to eq(cuenta_alternativa.id),
                                "expected cuenta_id=#{cuenta_alternativa.id} (alternativa), got #{pedido.cuenta_id}"

    # 9. Show page must reflect the alternate cuenta and Aceptado estado.
    expect(page).to have_content(alternate_label)
    expect(page).to have_content(/Aceptado/i)

    # 10. Visit pedidos index and verify the pedido appears with the alternate
    #     cuenta label and Aceptado estado (the index renders codigo as bare int).
    visit pedidos_path
    expect(page).to have_content(pedido.codigo.to_s)
    expect(page).to have_content(alternate_label)
    expect(page).to have_content(/Aceptado/i)

    # 11. Open the pedido detail again from a fresh load and re-verify the
    #     alternate cuenta + Aceptado estado survive a round-trip.
    visit pedido_path(pedido)
    expect(page).to have_content(alternate_label)
    expect(page).to have_content(/Aceptado/i)

    # 12. And the persisted state in the DB has not been silently rewritten
    #     by the asignar_cuenta callback on a subsequent save.
    pedido.reload
    expect(pedido.cuenta_id).to eq(cuenta_alternativa.id)
    expect(pedido.estado_id).to eq(2)
  end
end
