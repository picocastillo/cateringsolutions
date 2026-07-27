# frozen_string_literal: true

require 'rails_helper'

# Regression: when the cliente has `usuario_puede_elegir_cuenta` enabled and the
# user picks an alternate cuenta in the opciones "Enviar a" dropdown, that
# choice must survive subsequent saves on the pedido (cart edits, AJAX PATCHes,
# revisiting opciones, etc.). Previously, `Pedidos::Pedido#asignar_cuenta`
# (a before_validation callback) reverted `cuenta` back to `usuario.cuenta`
# on any save where the in-memory `@asigno_cuenta_manual` flag was missing —
# which is the case on every request that reloads the pedido from the DB.
RSpec.describe 'Opciones page — alternate cuenta persistence', :js, type: :system do
  let!(:tienda) do
    create(:tienda,
           nombre: 'Multi Cuenta Tienda',
           dominio: 'localhost',
           carrito_de_compras: true,
           horarios_de_entrega: false,
           maneja_stock: false)
  end

  let!(:cliente) do
    create(:cliente,
           tienda: tienda,
           nombre: 'Cliente Multi Cuenta',
           cuenta_corriente: false,
           horarios_de_entrega: false,
           usuario_puede_elegir_cuenta: true,
           permitir_envios_a_domicilio: false)
  end

  let!(:cuenta_default)     { create(:cuenta, nombre: 'Cuenta Default',     cliente: cliente, position: 1) }
  let!(:cuenta_alternativa) { create(:cuenta, nombre: 'Cuenta Alternativa', cliente: cliente, position: 2) }

  let!(:usuario) do
    create(:usuario, :cliente,
           login: 'multicuentauser',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Multi Cuenta User',
           email: 'multicuenta@test.com',
           cuenta: cuenta_default,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:categoria) { create(:categoria, nombre: 'Snacks', tienda: tienda, stock_activo: false) }
  let!(:producto)  { create(:producto,  nombre: 'Galletitas', tienda: tienda, categoria: categoria) }

  let!(:pedido) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta_default, estado_id: 1,
                       fecha: cuenta_default.proximo_dia_pedido,
                       autor: usuario, usuario: usuario)
    p.asignar_cuenta_manual
    p.cuenta = cuenta_default
    p.save!
    create(:producto_solicitado, pedido: p, producto: producto, cantidad: 2, precio_unitario: 100.0)
    p
  end

  before do
    create(:precio, :for_cliente, producto: producto, cliente: cliente,
                                  importe: 100, fecha_desde: Time.zone.today)

    visit root_path
    fill_in 'username', with: 'multicuentauser'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
  end

  it 'keeps the alternate cuenta selected after a follow-up save on the pedido' do
    default_label     = cuenta_default.cliente_y_nombre
    alternativa_label = cuenta_alternativa.cliente_y_nombre

    visit pedido_comprar_path(pedido)

    # Both cuentas should be available in the "Enviar a" dropdown.
    expect(page).to have_select('pedido_enviar_a_id', with_options: [default_label, alternativa_label])

    # User picks the alternate cuenta. The change handler PATCHes the pedido.
    select alternativa_label, from: 'pedido_enviar_a_id'

    # Wait for AJAX persistence.
    Timeout.timeout(10) do
      sleep 0.2 until pedido.reload.cuenta_id == cuenta_alternativa.id
    end

    # Stays on comprar page after AJAX.
    expect(page).to have_current_path(pedido_comprar_path(pedido), wait: 5)

    # Now simulate any subsequent request that saves the pedido — e.g. the very
    # same AJAX PATCH that the opciones page fires when the user changes turno,
    # or the saves done by `cambiar_categoria` / `actualizar_desde_carrito`.
    # We hit the existing `update` endpoint directly through the app's session.
    page.execute_script(<<~JS)
      $.ajax({
        url: '/pedidos/#{pedido.id}',
        method: 'PATCH',
        async: false,
        data: { pedido: { turno_entrega_id: '' } },
        headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') }
      });
    JS

    # The chosen alternate cuenta must survive the save.
    expect(pedido.reload.cuenta_id).to eq(cuenta_alternativa.id)

    # And the UI must still reflect the alternate choice when the user revisits.
    visit pedido_comprar_path(pedido)
    expect(page).to have_select('pedido_enviar_a_id', selected: alternativa_label)
  end
end
