# frozen_string_literal: true

require 'rails_helper'

# Covers: domicilio shipping option on the opciones checkout page.
# Conditions: permitir_envios_a_domicilio=true, cuenta_corriente=false (MP flow),
# carrito_de_compras=true → shows opciones page with enviar_a dropdown.
RSpec.describe 'Enviar a domicilio en opciones', :js, type: :system do
  let!(:tienda) do
    create(:tienda,
           nombre: 'Domicilio Store',
           dominio: 'localhost',
           carrito_de_compras: true,
           horarios_de_entrega: false,
           maneja_stock: false)
  end

  let!(:cliente) do
    create(:cliente,
           nombre: 'Cliente Domicilio',
           tienda: tienda,
           dia_inicio_ciclo_facturacion: 1,
           vencimiento_a: 30,
           horarios_de_entrega: false,
           usuario_puede_elegir_cuenta: false,
           permitir_envios_a_domicilio: true,
           cuenta_corriente: false,
           listas_de_precio_privada: false)
  end

  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta Domicilio', cliente: cliente, cuenta_corriente_parcial: nil) }

  let!(:usuario) do
    create(:usuario, :cliente,
           login: 'domiciliouser',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Domicilio User',
           email: 'domicilio@example.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:categoria) do
    create(:categoria, nombre: 'Comidas Dom', tienda: tienda, stock_activo: false, menu_diario: false)
  end

  let!(:producto) { create(:producto, nombre: 'Pizza Muzzarella', tienda: tienda, categoria: categoria) }

  let!(:pedido) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: cuenta.proximo_dia_pedido, autor: usuario, usuario: usuario)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    create(:producto_solicitado, pedido: p, producto: producto, cantidad: 1, precio_unitario: 400.0)
    p
  end

  before do
    create(:categoria, nombre: 'Menu Dummy', tienda: tienda, menu_diario: true)
    cliente.categorias << categoria
    create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 400,
                                  fecha_desde: Time.zone.today)

    visit root_path
    fill_in 'username', with: 'domiciliouser'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    page.assert_no_current_path('/', wait: 10)
  end

  it 'comprar page shows the Enviar a dropdown with Domicilio Particular option' do
    visit pedido_comprar_path(pedido)
    expect(page).to have_css('#show-pedido', wait: 10)

    expect(page).to have_select('pedido_enviar_a_id', wait: 5)
    expect(page).to have_css("option[value='-1']", visible: :all)
    expect(page).to have_content('Domicilio Particular')
  end

  it 'selecting Domicilio Particular reveals the direccion input' do
    visit pedido_comprar_path(pedido)
    expect(page).to have_css('#show-pedido', wait: 10)
    expect(page).to have_select('pedido_enviar_a_id', wait: 5)

    # Direction field should start hidden
    expect(page).to have_css('#wraper-direccion.hide', visible: :all)

    # Select domicilio
    page.select 'Domicilio Particular', from: 'pedido_enviar_a_id'

    # Direction field should now be visible
    expect(page).not_to have_css('#wraper-direccion.hide', visible: :all, wait: 3)
    expect(page).to have_field('pedido_direccion_envio', visible: :visible, wait: 3)
  end

  it 'entering an address with Domicilio selected persists direccion via AJAX' do
    visit pedido_comprar_path(pedido)
    expect(page).to have_css('#show-pedido', wait: 10)
    expect(page).to have_select('pedido_enviar_a_id', wait: 5)

    page.select 'Domicilio Particular', from: 'pedido_enviar_a_id'
    expect(page).to have_field('pedido_direccion_envio', visible: :visible, wait: 3)

    fill_in 'pedido_direccion_envio', with: 'Av. Corrientes 1234, CABA'
    # Trigger blur to fire the AJAX PATCH handler
    page.execute_script("$('#pedido_direccion_envio').blur()")

    # Wait for AJAX to complete and persist on the server
    expect(page).to have_current_path(%r{/pedidos/\d+/comprar}, wait: 5)
    Timeout.timeout(10) do
      sleep 0.2 until pedido.reload.direccion_envio == 'Av. Corrientes 1234, CABA'
    end
    expect(pedido.reload.enviar_a_id).to eq(-1)
  end

  it 'staying on comprar without entering an address keeps Domicilio Particular UI' do
    visit pedido_comprar_path(pedido)
    expect(page).to have_css('#show-pedido', wait: 10)
    expect(page).to have_select('pedido_enviar_a_id', wait: 5)

    page.select 'Domicilio Particular', from: 'pedido_enviar_a_id'
    expect(page).to have_field('pedido_direccion_envio', visible: :visible, wait: 3)

    # We stay on comprar page; direccion remains empty.
    expect(page).to have_current_path(%r{/pedidos/\d+/comprar}, wait: 5)
    expect(pedido.reload.direccion_envio).to be_blank
  end
end
