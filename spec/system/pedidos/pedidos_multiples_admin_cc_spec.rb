require 'rails_helper'

# System spec: admin creates a PedidoMultiple for a cuenta (no specific usuario)
# with cuenta corriente enabled, visits the resumen page, and finalizes all pedidos.
#
# Bug (before fix): the model validation `validates :usuario, presence` was firing
# for admin-created pedidos because `cuando_validar_usuario?` only checked
# `pedido_para_empresa`, not whether the author (admin) is a cliente user.
# Admin-created pedidos for cuentas legitimately have no `usuario_id`, so the
# validation must be skipped when `autor` is not a cliente user.
RSpec.describe 'PedidosMultiples — Admin finaliza grupo sin usuario (CC)', :js, type: :system do
  let!(:tienda) do
    create(:tienda, nombre: 'Admin CC Tienda', dominio: 'localhost',
                    carrito_de_compras: true, maneja_stock: false,
                    horarios_de_entrega: false)
  end
  let!(:pedido1) { make_admin_pedido(fecha: fecha1) }
  let!(:pedido2) { make_admin_pedido(fecha: fecha2) }

  let!(:admin) do
    create(:usuario, :admin, :with_password,
           login: 'admin_cc_test', nombre: 'Admin CC',
           email: 'admin_cc_test@example.com',
           visualizando_tienda: tienda).tap { |u| u.tiendas << tienda unless u.tiendas.include?(tienda) }
  end

  let!(:cliente) do
    create(:cliente, tienda: tienda, nombre: 'Empresa CC Test',
                     cuenta_corriente: true,
                     horarios_de_entrega: false,
                     usuario_puede_elegir_cuenta: false,
                     permitir_envios_a_domicilio: false)
  end

  # cuenta_corriente_parcial: true so cuenta_corriente_habilitada? returns true
  # and the "Finalizar todos" button is shown on resumen
  let!(:cuenta) do
    create(:cuenta, nombre: 'Cuenta CC Test', cliente: cliente,
                    cuenta_corriente_parcial: true)
  end

  let!(:categoria) { create(:categoria, nombre: 'CC Cat', tienda: tienda, stock_activo: false) }
  let!(:producto) { create(:producto, nombre: 'Producto CC', tienda: tienda, categoria: categoria) }

  # PedidoMultiple owned only by cuenta (no usuario) — mirrors real admin flow
  let!(:grupo) { Pedidos::PedidoMultiple.create!(cuenta: cuenta) }

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

  # Creates a pedido with only cuenta set (no usuario) and pedido_para_empresa: false
  # to reproduce the bug: the model validation was incorrectly requiring usuario.
  def make_admin_pedido(fecha:)
    p = Pedidos::Pedido.new(
      tienda: tienda, cuenta: cuenta,
      estado_id: 1, fecha: fecha,
      autor: admin, usuario: nil,
      pedido_multiple_id: grupo.id,
      pedido_para_empresa: false # intentionally false to reproduce the bug
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
    admin_login(admin)
  end

  it 'muestra el botón Finalizar todos para pedidos con cuenta corriente' do
    visit resumen_pedido_multipl_path(grupo)

    expect(page).to have_button('Finalizar todos', wait: 5)
    expect(page).not_to have_css('button[disabled]', text: 'Pagar con Mercado Pago')
  end

  it 'finaliza todos los pedidos sin error de usuario ausente y redirige a pedidos' do
    visit resumen_pedido_multipl_path(grupo)

    accept_confirm do
      click_button('Finalizar todos', wait: 5)
    end

    # Must redirect to pedidos index with success message
    expect(page).to have_current_path(pedidos_path, wait: 15)
    expect(page).to have_content('finalizados correctamente', wait: 5)

    # Verify both pedidos transitioned to estado aceptado (2)
    expect(pedido1.reload.estado_id).to eq(2)
    expect(pedido2.reload.estado_id).to eq(2)
  end

  it 'no muestra el botón de MercadoPago (cuenta corriente activa)' do
    visit resumen_pedido_multipl_path(grupo)

    # cuenta_corriente_habilitada? is true → only CC flow, no MP button
    expect(page).not_to have_button('Pagar con Mercado Pago', wait: 3)
  end
end
