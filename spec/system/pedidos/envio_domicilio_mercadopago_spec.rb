# frozen_string_literal: true

require 'rails_helper'

# Regression: clientes whose cliente has `usuario_puede_elegir_cuenta` +
# `permitir_envios_a_domicilio` (typical "empleados de una empresa" setup) can
# choose between delivery to the empresa (a cuenta) or to their own home
# ("Domicilio Particular"). Users reported that after picking "Domicilio
# Particular" and typing an address, the pedido was STILL being paid/delivered
# as "enviar a la empresa".
#
# Root cause: selecting "Domicilio Particular" (a `change` on
# `#pedido_enviar_a_id`) only toggled the UI and never persisted
# `envio_a_domicilio = true`. The only persistence path was the address field's
# `blur` handler, so the flag could stay `false` at payment time (race / blur
# never firing), and MercadoPago was charged for the empresa.
RSpec.describe 'Comprar — envío a domicilio persistence before MercadoPago payment', :js, type: :system do
  let(:captured_preferences) { [] }

  let!(:tienda) do
    create(:tienda,
           nombre: 'Domicilio MP Tienda',
           dominio: 'localhost',
           telefono: '123456789',
           email: 'domicilio@mp.com',
           carrito_de_compras: true,
           horarios_de_entrega: false,
           maneja_stock: false,
           costo_envio_domicilio: 500)
  end

  let!(:cliente) do
    create(:cliente,
           tienda: tienda,
           nombre: 'Empleados Empresa',
           cuenta_corriente: false,
           horarios_de_entrega: false,
           usuario_puede_elegir_cuenta: true,
           permitir_envios_a_domicilio: true)
  end

  let!(:cuenta) { create(:cuenta, nombre: 'Empresa', cliente: cliente, cuenta_corriente_parcial: nil) }

  let!(:usuario) do
    create(:usuario, :cliente,
           login: 'empleadodomicilio',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Empleado Domicilio',
           email: 'empleado@domicilio.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:categoria) { create(:categoria, nombre: 'Comidas', tienda: tienda, stock_activo: false, menu_diario: false) }
  # Dummy daily-menu category avoids empty-array SQL issues on the comprar page.
  let!(:categoria_menu) { create(:categoria, nombre: 'Menu Diario Dummy', tienda: tienda, menu_diario: true) }
  let!(:producto) { create(:producto, nombre: 'Milanesa', codigo: 'MIL001', tienda: tienda, categoria: categoria) }

  let!(:pedido) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: cuenta.proximo_dia_pedido,
                       autor: usuario, usuario: usuario)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    create(:producto_solicitado, pedido: p, producto: producto, cantidad: 2, precio_unitario: 100.0)
    p
  end

  before do
    create(:precio, :for_cliente, producto: producto, cliente: cliente,
                                  importe: 100, fecha_desde: Time.zone.today)
    cliente.categorias << categoria unless cliente.categorias.include?(categoria)

    # Stub the MercadoPago SDK so the test never hits the external API. Capture
    # every preference payload so we can assert what the user would actually be
    # charged for.
    prefs = captured_preferences
    mp_preference = double('preference')
    allow(mp_preference).to receive(:create) do |data|
      prefs << data
      { response: { 'id' => 'TEST-fake-preference-id-12345' } }
    end
    mp_sdk = double('sdk', preference: mp_preference)
    allow(Mercadopago::SDK).to receive(:new).and_return(mp_sdk)

    visit root_path
    fill_in 'username', with: 'empleadodomicilio'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
  end

  it 'marks the pedido as envío a domicilio the moment it is selected (not left as enviar a empresa)' do
    visit pedido_comprar_path(pedido)

    expect(page).to have_select('pedido_enviar_a_id')
    # Baseline: the pedido starts as "enviar a empresa".
    expect(pedido.reload.envio_a_domicilio).to be false

    select 'Domicilio Particular', from: 'pedido_enviar_a_id'

    # The MP button must become disabled with a hint asking for the address —
    # which only happens once the server has already recorded the pedido as
    # envío a domicilio. With the bug, nothing is persisted so this never shows.
    expect(page).to have_content('Ingresá la dirección de envío a domicilio', wait: 10)

    # The flag must be persisted BEFORE the user can pay, otherwise MercadoPago
    # would be charged/delivered to the empresa.
    expect(pedido.reload.envio_a_domicilio).to be(true)
  end

  it 'charges the MercadoPago payment to the domicilio after the address is entered' do
    visit pedido_comprar_path(pedido)
    expect(page).to have_select('pedido_enviar_a_id')

    select 'Domicilio Particular', from: 'pedido_enviar_a_id'
    expect(page).to have_css('#wraper-direccion:not(.hide)', wait: 10)

    fill_in 'pedido_direccion_envio', with: 'carlo 345'
    # Blur the address field to persist it (native blur bubbles as focusout,
    # which the delegated jQuery handler listens to).
    page.execute_script("document.getElementById('pedido_direccion_envio').blur()")

    # Once the address is set, the MP button renders for the domicilio pedido.
    expect(page).to have_css('#mp-boton-container', wait: 15)

    pedido.reload
    expect(pedido.envio_a_domicilio).to be(true)
    expect(pedido.direccion_envio).to eq('carlo 345')

    # The MercadoPago preference (what the user is charged) must reflect the home
    # delivery: it includes the "Envío a domicilio" line item and the pedido's
    # external_reference — proving the charge is NOT for the empresa.
    last_preference = captured_preferences.last
    expect(last_preference).to be_present
    titles = last_preference[:items].pluck(:title)
    expect(titles).to include('Envío a domicilio')
    expect(last_preference[:external_reference]).to eq("#{pedido.id}-#{usuario.id}")
  end
end
