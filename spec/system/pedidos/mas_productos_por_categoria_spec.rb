# frozen_string_literal: true

require 'rails_helper'

# Feature: tienda.muestra_mas_productos_por_categoria override + categoria.vender_en_carrito.
#
# When `tienda.muestra_mas_productos_por_categoria?` is true, the "Más Productos"
# panel only renders products belonging to categorias whose `vender_en_carrito`
# flag is true — overriding the legacy `muestra_mas_productos` flag.
RSpec.describe 'Más Productos por Categoría', :js, type: :system do
  let!(:tienda) do
    create(:tienda,
           nombre: 'Tienda Carrito Cat',
           dominio: 'localhost',
           carrito_de_compras: true,
           horarios_de_entrega: false,
           maneja_stock: false,
           soporta_productos_diarios: false,
           muestra_menus_del_dia: false,
           muestra_mas_productos: true,
           muestra_mas_productos_por_categoria: true)
  end

  let!(:cliente) do
    create(:cliente,
           tienda: tienda,
           nombre: 'Cliente CC',
           cuenta_corriente: false,
           horarios_de_entrega: false,
           permitir_envios_a_domicilio: false,
           usuario_puede_elegir_cuenta: false)
  end

  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta CC', cliente: cliente) }

  let!(:usuario) do
    create(:usuario, :cliente,
           login: 'ccuser',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'CC User',
           email: 'cc@test.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:cat_visible) do
    create(:categoria, nombre: 'EnCarrito', tienda: tienda, stock_activo: false, vender_en_carrito: true)
  end
  let!(:cat_oculta) do
    create(:categoria, nombre: 'NoEnCarrito', tienda: tienda, stock_activo: false, vender_en_carrito: false)
  end

  let!(:prod_visible) { create(:producto, nombre: 'Producto Visible', tienda: tienda, categoria: cat_visible) }
  let!(:prod_oculto)  { create(:producto, nombre: 'Producto Oculto',  tienda: tienda, categoria: cat_oculta) }

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
    create(:precio, :for_cliente, producto: prod_visible, cliente: cliente, importe: 100, fecha_desde: Time.zone.today)
    create(:precio, :for_cliente, producto: prod_oculto,  cliente: cliente, importe: 200, fecha_desde: Time.zone.today)

    visit root_path
    fill_in 'username', with: 'ccuser'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
  end

  context 'when tienda.muestra_mas_productos_por_categoria is true' do
    it 'shows products only from categorias with vender_en_carrito = true' do
      visit edit_pedido_path(pedido)

      expect(page).to have_css('#mas-productos-section', wait: 10)
      expect(page).to have_css("#cantidad_producto_#{prod_visible.id}", wait: 10)
      expect(page).to have_no_css("#cantidad_producto_#{prod_oculto.id}")
    end

    it 'limits the categoria selector to vendibles_en_carrito' do
      visit edit_pedido_path(pedido)

      expect(page).to have_css('#categoria-selector', visible: :all, wait: 10)
      options = page.all('#categoria-selector option', visible: :all).map { |o| o.text(:all).strip }
      expect(options).to include('EnCarrito')
      expect(options).not_to include('NoEnCarrito')
    end
  end

  context 'when tienda.muestra_mas_productos_por_categoria is false (legacy flag only)' do
    before do
      tienda.update!(muestra_mas_productos_por_categoria: false, muestra_mas_productos: true)
    end

    it 'shows products from ALL categorias regardless of vender_en_carrito' do
      visit edit_pedido_path(pedido)

      expect(page).to have_css('#mas-productos-section', wait: 10)
      expect(page).to have_css("#cantidad_producto_#{prod_visible.id}", wait: 10)
      expect(page).to have_css("#cantidad_producto_#{prod_oculto.id}", wait: 10)
    end
  end

  context 'when both flags are false' do
    before do
      tienda.update!(muestra_mas_productos: false, muestra_mas_productos_por_categoria: false)
    end

    it 'does not render the Más Productos section at all' do
      visit edit_pedido_path(pedido)

      expect(page).to have_no_css('#mas-productos-section')
    end
  end
end
