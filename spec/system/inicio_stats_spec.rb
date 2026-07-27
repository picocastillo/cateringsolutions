# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Inicio Stats AJAX', :js, type: :system do
  around do |example|
    original = ENV.fetch('DISABLED_CHARTS', nil)
    ENV['DISABLED_CHARTS'] = 'false'
    example.run
  ensure
    ENV['DISABLED_CHARTS'] = original
  end

  let(:tienda) { create(:tienda, nombre: 'Stats Store', carrito_de_compras: true) }
  let(:admin) { create(:usuario, :admin, :with_password, visualizando_tienda: tienda) }

  before do
    admin.tiendas << tienda unless admin.tiendas.include?(tienda)

    # Create minimal data so stats has something to display
    categoria = create(:categoria, tienda: tienda, nombre: 'Cat Stats')
    producto = create(:producto, tienda: tienda, categoria: categoria, nombre: 'Producto Stats')
    create(:precio, producto: producto, importe: 100)
    cliente = create(:cliente, tienda: tienda)
    cuenta = create(:cuenta, cliente: cliente)

    pedido = Pedidos::Pedido.new(
      tienda: tienda, cuenta: cuenta, fecha: 1.week.ago.to_date,
      estado_id: 1, autor: admin, usuario: admin
    )
    pedido.save(validate: false)
    ps = Productos::ProductoSolicitado.new(
      pedido: pedido, producto: producto, cantidad: 5,
      precio_unitario: 100, precio_con_descuento: 100
    )
    ps.save(validate: false)
    pedido.update_column(:estado_id, 3) # confirmado
  end

  it 'loads historical stats via AJAX on the inicio page' do
    admin_login(admin, 'password123')
    visit inicio_index_path

    # The per-widget containers should exist immediately (charts now lazy-load individually)
    expect(page).to have_css('#widget-stats_top_productos', wait: 10)
    expect(page).to have_css('#widget-stats_top_menus_diarios', wait: 5)
    expect(page).to have_css('#widget-stats_usuarios_chart', wait: 5)

    # Wait for AJAX to complete - spinners should disappear as widgets load
    expect(page).to have_no_text('Cargando...', wait: 25)
  end
end
