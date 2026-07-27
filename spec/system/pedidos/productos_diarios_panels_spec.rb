# frozen_string_literal: true

require 'rails_helper'

# Feature: "Nuestras opciones del día" panel.
#
# When `tienda.soporta_productos_diarios?` is true, every `MenusDiarios::MenuDiario`
# with `tipo_id = 2 (productos_diarios)` for the pedido's fecha must render as a
# product panel between the legacy "Menús del Día" cards (tipo_id = 1) and the
# "Más Productos" section. When the flag is false, the section must NOT render.
RSpec.describe 'Productos del día panels', :js, type: :system do
  let!(:tienda) do
    create(:tienda,
           nombre: 'Tienda PD',
           dominio: 'localhost',
           carrito_de_compras: true,
           horarios_de_entrega: false,
           maneja_stock: false,
           soporta_productos_diarios: true)
  end

  let!(:cliente) do
    create(:cliente,
           tienda: tienda,
           nombre: 'Cliente PD',
           cuenta_corriente: false,
           horarios_de_entrega: false,
           permitir_envios_a_domicilio: false,
           usuario_puede_elegir_cuenta: false)
  end

  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta PD', cliente: cliente) }

  let!(:usuario) do
    create(:usuario, :cliente,
           login: 'pduser',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'PD User',
           email: 'pd@test.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:categoria_normal)  { create(:categoria, nombre: 'Bebidas', tienda: tienda, stock_activo: false) }
  let!(:categoria_diaria)  { create(:categoria, nombre: 'Diarios', tienda: tienda, stock_activo: false) }
  let!(:producto_normal)   { create(:producto,  nombre: 'Agua mineral', tienda: tienda, categoria: categoria_normal) }
  let!(:producto_diario_a) { create(:producto,  nombre: 'Especial del día A', tienda: tienda, categoria: categoria_diaria) }
  let!(:producto_diario_b) { create(:producto,  nombre: 'Especial del día B', tienda: tienda, categoria: categoria_diaria) }

  let(:fecha) { cuenta.proximo_dia_pedido }

  let!(:pedido) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: fecha, autor: usuario, usuario: usuario)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    p
  end

  before do
    create(:precio, :for_cliente, producto: producto_normal,   cliente: cliente, importe: 100, fecha_desde: Time.zone.today)
    create(:precio, :for_cliente, producto: producto_diario_a, cliente: cliente, importe: 250, fecha_desde: Time.zone.today)
    create(:precio, :for_cliente, producto: producto_diario_b, cliente: cliente, importe: 350, fecha_desde: Time.zone.today)

    visit root_path
    fill_in 'username', with: 'pduser'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
  end

  context 'when tienda supports productos_diarios and there are matching menus' do
    let!(:menu_pd) do
      MenusDiarios::MenuDiario.create!(productos: [producto_diario_a, producto_diario_b],
                                       fecha: fecha, descripcion: 'Selección del Chef',
                                       tienda: tienda, autor: usuario,
                                       tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
    end

    it 'renders the "Nuestras opciones del día" section with the menu products' do
      visit edit_pedido_path(pedido)

      within('#opciones-del-dia-section') do
        expect(page).to have_content('Nuestras opciones del día')
        expect(page).to have_content('Selección del Chef')
        expect(page).to have_css("#cantidad_producto_#{producto_diario_a.id}")
        expect(page).to have_css("#cantidad_producto_#{producto_diario_b.id}")
      end
    end

    it 'lazy-loads the panel via AJAX (placeholder is replaced async)' do
      visit edit_pedido_path(pedido)

      # The placeholder spinner should be replaced by the rendered section.
      expect(page).to have_css('#opciones-del-dia-section', wait: 10)
      expect(page).to have_no_css('#opciones-del-dia-loader', wait: 10)
    end

    it 'allows adding a producto del día to the cart and persists it' do
      visit edit_pedido_path(pedido)
      expect(page).to have_css('#opciones-del-dia-section', wait: 10)

      # Click the + button inside the producto card for producto_diario_a (within the panel).
      within('#opciones-del-dia-section') do
        within("#cantidad_producto_#{producto_diario_a.id}") do
          find('a.cambiadores-cantidad.mas').click
        end
      end

      # Wait for the cantidad input to reflect the new quantity.
      within('#opciones-del-dia-section') do
        expect(page).to have_css("#input_cantidad_#{producto_diario_a.id}.mayorcero", wait: 10)
        expect(find("#input_cantidad_#{producto_diario_a.id}").value.to_i).to eq(1)
      end

      # Verify the ProductoSolicitado was created server-side.
      ps = nil
      10.times do
        ps = pedido.productos_solicitados.reload.find { |x| x.producto_id == producto_diario_a.id }
        break if ps

        sleep 0.3
      end
      expect(ps).to be_present
      expect(ps.cantidad).to eq(1)
    end
  end

  context 'when tienda does not support productos_diarios' do
    before do
      tienda.update!(soporta_productos_diarios: false)
      MenusDiarios::MenuDiario.create!(productos: [producto_diario_a],
                                       fecha: fecha, descripcion: 'Selección del Chef',
                                       tienda: tienda, autor: usuario,
                                       tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
    end

    it 'does not render the section' do
      visit edit_pedido_path(pedido)
      expect(page).to have_no_css('#opciones-del-dia-section')
      expect(page).to have_no_content('Nuestras opciones del día')
    end
  end
end
