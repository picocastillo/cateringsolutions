# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Productos Show', :js, type: :system do
  let(:tienda) { create(:tienda, nombre: 'Show Store') }
  let(:admin) { create(:usuario, :admin, :with_password, visualizando_tienda: tienda) }
  let(:categoria) { create(:categoria, tienda: tienda, nombre: 'Comidas') }
  let(:producto) do
    create(:producto, tienda: tienda, categoria: categoria,
                      nombre: 'Milanesa Napolitana', codigo: 'MIL001')
  end

  before do
    admin.tiendas << tienda unless admin.tiendas.include?(tienda)

    # Create a precio with client association for the precios table
    cliente = create(:cliente, tienda: tienda, nombre: 'Cliente Restaurante')
    create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 2500.0)
  end

  it 'displays product details and prices' do
    admin_login(admin, 'password123')
    visit producto_path(producto)

    # Product header and details
    expect(page).to have_text('Milanesa Napolitana', wait: 10)
    expect(page).to have_text('MIL001')
    expect(page).to have_text('Comidas')

    # Precios section should be present
    expect(page).to have_text('Precios', wait: 5)
    expect(page).to have_text('Cliente Restaurante')
  end
end
