# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stock Movimientos Usuario Tracking', type: :system do
  let(:tienda) { create(:tienda, maneja_stock: true) }
  let(:usuario) { create(:usuario, :admin, visualizando_tienda: tienda, email: 'test@example.com') }
  let(:local) { create(:local, tienda: tienda, nombre: 'Local Principal', domicilio: 'Calle Test 123', telefono: '123456789') }
  let(:categoria) { create(:categoria, tienda: tienda, nombre: 'Categoría Test', stock_activo: true) }
  let(:producto) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Producto Test') }
  let!(:stock) do
    producto.stocks.first.tap { |s| s.update!(cantidad_actual: 50, cantidad_minima: 10, local: local) }
  end

  before do
    usuario.tiendas << tienda unless usuario.tiendas.include?(tienda)
    driven_by(:selenium_remote)
    login_as(usuario)
  end

  it 'displays the usuario who made the adjustment, not "sistema"' do
    visit "/stocks/#{stock.id}"

    # Adjust stock manually
    fill_in 'Nueva Cantidad', with: '75'
    fill_in 'Motivo', with: 'Reposición manual de inventario'
    click_button 'Ajustar Stock'

    # Should see success message
    expect(page).to have_content('Stock ajustado correctamente')

    # Click on movimientos link
    click_link 'Movimientos'

    # Should see the movement with the actual user name (not email), not "sistema"
    expect(page).to have_content(usuario.nombre)
    expect(page).to have_content('Reposición manual de inventario')
    expect(page).to have_content('Ajuste entrada')
    expect(page).to have_content('25') # diferencia (75 - 50)

    # Ensure it's NOT showing "sistema"
    within('table tbody tr:first-child') do
      expect(page).not_to have_content('sistema')
      expect(page).to have_content(usuario.nombre)
    end
  end

  it 'shows the usuario for all types of manual adjustments' do
    visit "/stocks/#{stock.id}"

    # First adjustment: increase
    fill_in 'Nueva Cantidad', with: '60'
    fill_in 'Motivo', with: 'Aumento de stock'
    click_button 'Ajustar Stock'

    # Second adjustment: decrease
    fill_in 'Nueva Cantidad', with: '45'
    fill_in 'Motivo', with: 'Reducción de stock'
    click_button 'Ajustar Stock'

    # View movimientos
    click_link 'Movimientos'

    # Both movements should show the user name
    movements_table = page.find('table tbody')
    expect(movements_table).to have_content(usuario.nombre, count: 2)
    expect(movements_table).to have_content('Aumento de stock')
    expect(movements_table).to have_content('Reducción de stock')

    # Verify no "sistema" appears for these manual adjustments
    rows = movements_table.all('tr')
    rows.each do |row|
      expect(row).not_to have_content('sistema') if row.has_content?('Aumento de stock') || row.has_content?('Reducción de stock')
    end
  end
end
