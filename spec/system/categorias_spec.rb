require 'rails_helper'

RSpec.describe 'Categorias Management', :js, type: :system do
  before do
    @tienda = create(:tienda, nombre: 'Test Store for Categorias')
    @admin_user = create(:usuario, :admin,
                         nombre: 'Admin Categorias',
                         login: 'categoriaadmin',
                         password: 'cat123',
                         password_confirmation: 'cat123',
                         visualizando_tienda: @tienda)
  end

  def login_as_admin
    visit root_path
    fill_in 'username', with: @admin_user.login
    fill_in 'password', with: 'cat123'
    click_button 'Iniciar sesión'

    # Wait for redirect after login
    expect(page).to have_current_path('/inicio', wait: 5)
  end

  context 'Categorias Index' do
    before do
      @categoria1 = create(:categoria, tienda: @tienda, nombre: 'Bebidas', codigo: 'BEB001', stock_activo: true)
      @categoria2 = create(:categoria, tienda: @tienda, nombre: 'Alimentos', codigo: 'ALI001', stock_activo: false)
      @categoria3 = create(:categoria, tienda: @tienda, nombre: 'Postres', codigo: 'POS001', stock_activo: true)
    end

    it 'displays all categorias with their attributes' do
      login_as_admin

      visit '/categorias'

      # Verify page loaded
      expect(page).to have_content('Categorías')

      # Verify all categorias are displayed by name (codigo is auto-generated)
      expect(page).to have_content('Bebidas')
      expect(page).to have_content('Alimentos')
      expect(page).to have_content('Postres')

      # Verify table headers
      expect(page).to have_content('Código')
      expect(page).to have_content('Nombre')
      expect(page).to have_content('Stock Activo')
      expect(page).to have_content('Activo')
    end

    it 'displays stock_activo status for each categoria' do
      login_as_admin

      visit '/categorias'

      # Check that stock activo column is present
      within('#categorias') do
        # Find the rows with our categorias
        bebidas_row = page.find('tr', text: 'Bebidas')
        alimentos_row = page.find('tr', text: 'Alimentos')

        # Verify stock activo status
        expect(bebidas_row).to have_css('.label-success', text: 'Sí')
        expect(alimentos_row).to have_css('.label-default', text: 'No')
      end
    end
  end

  context 'Creating a new Categoria' do
    it 'creates a categoria with stock_activo enabled' do
      login_as_admin

      visit '/categorias'

      # Click new button
      click_link 'Nuevo'

      # Wait for modal to appear
      within('.modal', wait: 10) do
        expect(page).to have_content('Nuevo Categoría')

        # Fill in the form
        fill_in 'categoria_nombre', with: 'Snacks'
        fill_in 'categoria_descripcion', with: 'Productos de snacks'

        # Use JavaScript to set the checkbox (SimpleForm wraps it)
        page.execute_script("document.getElementById('categoria_stock_activo').checked = true;")

        # Submit form
        click_button 'Crear'
      end

      # Verify categoria was created
      expect(page).to have_content('Snacks')

      # Verify in database
      categoria = Productos::Categoria.find_by(nombre: 'Snacks')
      expect(categoria).to be_present
      expect(categoria.stock_activo).to be true
      expect(categoria.descripcion).to eq('Productos de snacks')
    end

    it 'creates a categoria with stock_activo disabled' do
      login_as_admin

      visit '/categorias'

      click_link 'Nuevo'

      within('.modal', wait: 10) do
        fill_in 'categoria_nombre', with: 'Servicios'

        # Use JavaScript to ensure checkbox is unchecked (default is false)
        page.execute_script("document.getElementById('categoria_stock_activo').checked = false;")

        click_button 'Crear'
      end

      expect(page).not_to have_css('.modal', visible: true, wait: 5)

      # Verify in database
      categoria = Productos::Categoria.find_by(nombre: 'Servicios')
      expect(categoria).to be_present
      expect(categoria.stock_activo).to be false
    end
  end

  context 'Editing a Categoria' do
    before do
      @categoria = create(:categoria, tienda: @tienda, nombre: 'Original', descripcion: 'Original desc', stock_activo: false)
    end

    it 'updates categoria including stock_activo status' do
      login_as_admin

      visit '/categorias'

      # Find and click edit button for the categoria
      within('tr', text: 'Original') do
        find('i.ti-marker-alt').click
      end

      # Wait for modal
      within('.modal', wait: 10) do
        expect(page).to have_content('Editando Categoría')

        # Update fields
        fill_in 'categoria_nombre', with: 'Updated Name'
        fill_in 'categoria_descripcion', with: 'Updated description'

        # Enable stock_activo with JavaScript
        page.execute_script("document.getElementById('categoria_stock_activo').checked = true;")

        click_button 'Guardar'
      end

      # Verify changes
      expect(page).to have_content('Updated Name')

      # Verify in database
      @categoria.reload
      expect(@categoria.nombre).to eq('Updated Name')
      expect(@categoria.descripcion).to eq('Updated description')
      expect(@categoria.stock_activo).to be true
    end

    it 'can toggle stock_activo from true to false' do
      @categoria.update!(stock_activo: true)

      login_as_admin

      visit '/categorias'

      within('tr', text: 'Original') do
        find('i.ti-marker-alt').click
      end

      within('.modal', wait: 10) do
        # Disable stock_activo with JavaScript
        page.execute_script("document.getElementById('categoria_stock_activo').checked = false;")
        click_button 'Guardar'
      end

      expect(page).not_to have_css('.modal', visible: true, wait: 5)

      @categoria.reload
      expect(@categoria.stock_activo).to be false
    end
  end

  context 'Categoria Actions' do
    before do
      @categoria = create(:categoria, tienda: @tienda, nombre: 'Test Delete', stock_activo: true)
    end

    it 'displays action buttons for each categoria' do
      login_as_admin

      visit '/categorias'

      within('tr', text: 'Test Delete') do
        # Verify edit button exists
        expect(page).to have_css('i.ti-marker-alt')

        # Verify delete button exists (if user has permission)
        expect(page).to have_css('i.ti-trash')
      end
    end
  end

  context 'Integration with Stock Export' do
    it 'categoria with stock_activo appears correctly in stock exports' do
      categoria_activa = create(:categoria, tienda: @tienda, nombre: 'Export Test', stock_activo: true)
      producto = create(:producto, tienda: @tienda, nombre: 'Test Product', categoria: categoria_activa)
      stock = producto.stocks.first.tap { |s| s.update!(cantidad_actual: 10) }

      exporter = Productos::StocksExporter.new(
        params: { q: {} },
        autor: @admin_user
      )

      row_data = exporter.row(stock)

      # The categoria column should include stock status
      expect(row_data[3]).to eq('Export Test (stock activo)')
    end

    it 'categoria without stock_activo appears correctly in stock exports' do
      categoria_inactiva = create(:categoria, tienda: @tienda, nombre: 'No Stock Test', stock_activo: false)
      producto = create(:producto, tienda: @tienda, nombre: 'Test Product 2', categoria: categoria_inactiva)
      # Manually create stock since categoria has stock_activo: false
      stock = Productos::Stock.create!(
        producto: producto,
        tienda: @tienda,
        local_id: nil,
        cantidad_actual: 5,
        cantidad_minima: 0,
        activo: true
      )

      exporter = Productos::StocksExporter.new(
        params: { q: {} },
        autor: @admin_user
      )

      row_data = exporter.row(stock)

      expect(row_data[3]).to eq('No Stock Test (stock inactivo)')
    end
  end
end
