# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cargas Simples Pedidos Index', :js, type: :system do
  let(:tienda) { create(:tienda, nombre: 'CS Store', carrito_de_compras: true) }
  let(:admin) { create(:usuario, :admin, :with_password, visualizando_tienda: tienda) }

  before do
    admin.tiendas << tienda unless admin.tiendas.include?(tienda)
  end

  it 'renders the carga rápida page with form and pedidos list' do
    admin_login(admin, 'password123')
    visit cargas_simples_pedidos_path

    # Page title
    expect(page).to have_text('Carga', wait: 10)

    # Pedidos list section
    expect(page).to have_css('#listado-pedidos', wait: 10)

    # The new pedido form should have the "Para" selector
    expect(page).to have_select('pedido[tipo_pedido]')
  end

  context 'with existing pedidos' do
    before do
      cliente = create(:cliente, tienda: tienda)
      cuenta = create(:cuenta, cliente: cliente)
      categoria = create(:categoria, tienda: tienda)
      producto = create(:producto, tienda: tienda, categoria: categoria)

      pedido = Pedidos::Pedido.new(
        tienda: tienda, cuenta: cuenta, fecha: Date.current,
        estado_id: 2, autor: admin, usuario: admin
      )
      pedido.save(validate: false)
      ps = Productos::ProductoSolicitado.new(
        pedido: pedido, producto: producto,
        cantidad: 3, precio_unitario: 200, precio_con_descuento: 200
      )
      ps.save(validate: false)
    end

    it 'shows pedidos in the list section' do
      admin_login(admin, 'password123')
      visit cargas_simples_pedidos_path

      expect(page).to have_text('Pedidos', wait: 10)
      expect(page).to have_css('#listado-pedidos', wait: 10)
    end
  end
end
