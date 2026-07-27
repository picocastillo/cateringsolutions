# frozen_string_literal: true

require 'rails_helper'

# Regression test for: "Pagar" in pedidos multiples resumen required two clicks.
#
# Previous flow (buggy):
#   1. User sees a green "Pagar con Mercado Pago" button_to (click 1)
#   2. AJAX fires -> generar_pago_ml_multiple -> JS response calls co.render()
#   3. co.render() inserts a SECOND MercadoPago-branded button into #mp-boton-container
#   4. User must click the second button (click 2) to open the MP checkout modal
#
# Expected flow (fixed):
#   1. User clicks "Pagar con Mercado Pago" (click 1)
#   2. AJAX fires -> generar_pago_ml_multiple -> JS response uses autoOpen: true
#   3. MP checkout modal opens automatically -- NO second button, NO second click
#
# Verification strategy:
#   window.mpCheckoutAutoOpened is set to true in the JS response BEFORE
#   instantiating MercadoPago, so it is testable whether or not the CDN SDK loads.
#   Before fix: flag is never set (co.render path does not set it) -> assertion fails.
#   After  fix: flag is true                                       -> assertion passes.
RSpec.describe 'PedidosMultiples MP single-click checkout', :js, type: :system do
  def next_weekday(from = Date.current + 1.day)
    from += 1.day while from.saturday? || from.sunday?
    from
  end

  def make_pedido(fecha:, grupo:)
    p = build(:pedido, tienda: @tienda, cuenta: @cuenta, estado_id: 1,
                       fecha: fecha, autor: @user, usuario: @user,
                       pedido_multiple_id: grupo.id)
    p.asignar_cuenta_manual
    p.cuenta = @cuenta
    p.save!
    ps = Productos::ProductoSolicitado.new(
      pedido: p, producto: @producto, cantidad: 1, precio_unitario: 500.0
    )
    ps.save(validate: false)
    p
  end

  before do
    mp_preference = double('preference')
    allow(mp_preference).to receive(:create).and_return(
      { response: { 'id' => 'TEST-multi-single-click-pref' } }
    )
    mp_sdk = double('sdk', preference: mp_preference)
    allow(Mercadopago::SDK).to receive(:new).and_return(mp_sdk)

    @tienda = create(:tienda,
                     nombre: 'MultiMP SingleClick',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'multi@mp.com',
                     carrito_de_compras: true,
                     maneja_stock: false,
                     horarios_de_entrega: false)

    @cliente = create(:cliente,
                      nombre: 'Cliente MultiMP',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: false,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta, nombre: 'Cuenta MultiMP', cliente: @cliente,
                              cuenta_corriente_parcial: nil)

    @user = create(:usuario, :cliente,
                   login: 'multimpsingleclick',
                   password: 'password123',
                   password_confirmation: 'password123',
                   nombre: 'MultiMP Single Click User',
                   email: 'multimpsc@example.com',
                   cuenta: @cuenta,
                   tienda_cliente: @tienda,
                   visualizando_tienda: @tienda)

    @categoria = create(:categoria,
                        nombre: 'Cat MultiMP',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)
    create(:categoria, nombre: 'Menu Diario Dummy MultiMP', tienda: @tienda, menu_diario: true)
    @cliente.categorias << @categoria unless @cliente.categorias.include?(@categoria)

    @producto = create(:producto,
                       nombre: 'Producto MultiMP',
                       tienda: @tienda,
                       categoria: @categoria,
                       discontinued_at: nil)
    create(:precio, producto: @producto, importe: 500.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)

    allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante).and_return(true)

    @grupo = Pedidos::PedidoMultiple.create!(usuario: @user, cuenta: @cuenta)
    @pedido1 = make_pedido(fecha: next_weekday, grupo: @grupo)
    @pedido2 = make_pedido(fecha: next_weekday(next_weekday + 1.day), grupo: @grupo)

    driven_by :selenium_remote
    cliente_login(@user)
  end

  scenario 'clicking Pagar once opens checkout without a second button' do
    visit resumen_pedido_multipl_path(@grupo)

    expect(page).to have_button('Pagar con Mercado Pago', wait: 5)

    # Flag must be unset before any user action
    expect(page.evaluate_script('window.mpCheckoutAutoOpened')).to be_falsy

    click_button('Pagar con Mercado Pago')

    expect(page).to have_css('#mp-boton-container', wait: 15)
    wait_for_ajax
    sleep 0.5

    # BEFORE FIX: undefined (co.render path never sets this flag)
    # AFTER  FIX: true     (autoOpen:true set before MercadoPago instantiation)
    auto_opened = page.evaluate_script('window.mpCheckoutAutoOpened === true')
    expect(auto_opened).to be(true),
                           'Expected mpCheckoutAutoOpened===true after clicking Pagar. Before fix: co.render() rendered a second button requiring click 2. After fix: autoOpen:true triggers the MP modal immediately.'

    expect(page).not_to have_button('Pagar con Mercado Pago')
  end
end
