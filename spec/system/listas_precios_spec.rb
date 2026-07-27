require 'rails_helper'

RSpec.describe 'Listas de Precios', :js, type: :system do
  before do
    @tienda = create(:tienda, nombre: 'Test Store Precios')
    @admin_user = create(:usuario, :admin, :with_password,
                         nombre: 'Admin Precios',
                         login: 'preciosadmin',
                         visualizando_tienda: @tienda)
    @admin_user.tiendas << @tienda unless @admin_user.tiendas.include?(@tienda)
    @categoria = create(:categoria, tienda: @tienda, nombre: 'Bebidas')
  end

  def login_as_admin
    visit '/'
    fill_in 'username', with: @admin_user.login
    fill_in 'password', with: 'password123'
    page.find('button[type="submit"], input[type="submit"]', match: :first).click
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)
  end

  context 'Index page' do
    before do
      @producto1 = create(:producto, tienda: @tienda, categoria: @categoria, nombre: 'Coca Cola')
      @producto2 = create(:producto, tienda: @tienda, categoria: @categoria, nombre: 'Pepsi')
      @precio1 = create(:precio, producto: @producto1, importe: 150.0, fecha_desde: Date.current, fecha_hasta: Date.current + 1.year)
      @precio2 = create(:precio, producto: @producto2, importe: 200.0, fecha_desde: Date.current, fecha_hasta: Date.current + 1.year)
    end

    it 'displays precios with product info' do
      login_as_admin
      visit '/listas_precios'

      expect(page).to have_content('Listas de Precios')
      expect(page).to have_content('Coca Cola')
      expect(page).to have_content('Pepsi')
      expect(page).to have_content('Bebidas')

      # Verify table headers
      expect(page).to have_content('Producto')
      expect(page).to have_content('Importe')
      expect(page).to have_content('Fecha Desde')
      expect(page).to have_content('Fecha Hasta')
    end

    it 'shows action buttons' do
      login_as_admin
      visit '/listas_precios'

      expect(page).to have_content('Exportar')
      expect(page).to have_content('Importar')
      expect(page).to have_content('Eliminar duplicados')
    end

    it 'shows trash icon for each precio' do
      login_as_admin
      visit '/listas_precios'

      expect(page).to have_css('.ti-trash', count: 2)
    end

    it 'filters by product name', :js do
      login_as_admin
      visit '/listas_precios'

      # Expand filters
      page.find('.filtros .card-actions a[data-action="collapse"]').click
      sleep 0.5

      fill_in 'q[nombre_producto]', with: 'Coca Cola'
      click_button 'Buscar'

      expect(page).to have_content('Coca Cola', wait: 5)
      expect(page).not_to have_content('Pepsi')
    end

    it 'deletes individual precio via trash icon' do
      login_as_admin
      visit '/listas_precios'

      # Accept the confirm dialog
      accept_confirm do
        first('.ti-trash').find(:xpath, '..').click
      end

      expect(page).to have_content('Precio eliminado correctamente', wait: 5)
    end
  end

  context 'Eliminar duplicados' do
    before do
      @producto = create(:producto, tienda: @tienda, categoria: @categoria, nombre: 'Fanta')
      @dup1 = create(:precio, producto: @producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      @dup2 = create(:precio, producto: @producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
    end

    it 'removes duplicates after confirmation' do
      login_as_admin
      visit '/listas_precios'

      accept_confirm do
        click_link 'Eliminar duplicados'
      end

      expect(page).to have_content('Se eliminaron 1 precios duplicados', wait: 5)
    end
  end

  context 'Import dialog' do
    it 'opens import modal' do
      login_as_admin
      visit '/listas_precios'

      click_link 'Importar'
      expect(page).to have_content('Importar Precios', wait: 5)
      expect(page).to have_content('formato XLSX')
    end
  end

  context 'Duplicate indicators' do
    before do
      @producto = create(:producto, tienda: @tienda, categoria: @categoria, nombre: 'Sprite')
      create(:precio, producto: @producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      create(:precio, producto: @producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
    end

    it 'shows duplicate warning icons' do
      login_as_admin
      visit '/listas_precios'

      expect(page).to have_css('.ti-alert', minimum: 1)
    end
  end

  context 'Menu visibility' do
    it 'shows Listas de Precios in admin sidebar' do
      login_as_admin
      visit '/inicio'

      expect(page).to have_link('Listas de Precios', visible: :all)
    end
  end

  context 'Productos sin precio filter' do
    before do
      @prod_con_precio = create(:producto, tienda: @tienda, categoria: @categoria, nombre: 'Con Precio')
      @prod_sin_precio = create(:producto, tienda: @tienda, categoria: @categoria, nombre: 'Sin Precio')
      create(:precio, producto: @prod_con_precio, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 1.year)
    end

    it 'shows only products without active precio' do
      login_as_admin
      visit '/listas_precios'

      # Expand filters
      page.find('.filtros .card-actions a[data-action="collapse"]').click
      expect(page).to have_css('.filtros .card-body.collapse.show', wait: 5)

      find('label', text: 'Productos sin precio').click
      click_button 'Buscar'

      expect(page).to have_content('Sin Precio', wait: 5)
      expect(page).not_to have_content('Con Precio')
      # Verify different table columns
      expect(page).to have_css('th', text: 'Código')
    end
  end
end
