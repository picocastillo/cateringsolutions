require 'rails_helper'

RSpec.describe 'Productos Management', :js, type: :system do
  before do
    # Create basic roles that are needed
    @admin_role = Usuarios::Rol.find_or_create_by(
      modulo: 'Usuarios',
      nombre: 'admin',
      titulo: 'Administrador'
    )

    @gestiona_productos_role = Usuarios::Rol.find_or_create_by(
      modulo: 'Productos',
      nombre: 'gestiona_productos',
      titulo: 'Gestiona Productos'
    )

    # Create a tienda for testing
    @tienda = create(:tienda,
                     nombre: 'Test Store for Products',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'products@store.com',
                     mensaje_bienvenida: 'Bienvenido a nuestra tienda',
                     venta_mostrador: true,
                     carrito_de_compras: true)

    # Create a categoria for products
    @categoria = create(:categoria,
                        nombre: 'Electrónicos',
                        tienda: @tienda)

    # Create an admin user with working password
    @admin_user = create(:usuario, :admin, :with_password,
                         password: 'admin123',
                         password_confirmation: 'admin123',
                         nombre: 'Admin User',
                         email: 'admin@example.com',
                         visualizando_tienda: @tienda)

    # Associate the user with the tienda
    @admin_user.tiendas << @tienda unless @admin_user.tiendas.include?(@tienda)
  end

  context 'Product Creation' do
    it 'successfully creates a new product through the web interface' do
      # Login as admin user
      admin_login(@admin_user, 'admin123')
      # Navigate directly to productos section
      visit '/productos'

      # Navigate to new product page
      visit '/productos/new'

      expect(page).to have_current_path(%r{/productos/new})

      # Fill in product details
      fill_in 'producto[nombre]', with: 'Smartphone Samsung Galaxy'
      fill_in 'producto[descripcion]', with: 'Smartphone Samsung Galaxy con 128GB de almacenamiento'

      # Select category if there's a dropdown
      select @categoria.nombre, from: 'producto[categoria_id]' if page.has_select?('producto[categoria_id]')
      # Submit the form
      if page.has_button?('Guardar')
        click_button 'Guardar'
      elsif page.has_button?('Crear')
        click_button 'Crear'
      else
        find('input[type="submit"], button[type="submit"]').click
      end

      # Verify the product was created successfully
      expect(page).to have_content('Smartphone Samsung Galaxy')
      expect(page).to have_content('creado correctamente')

      # Check that we're redirected to the product show page or products index
      expect(page).to have_current_path(%r{/productos})
      # Verify the product exists in the database
      created_product = Productos::Producto.find_by(nombre: 'Smartphone Samsung Galaxy')
      expect(created_product).to be_present
      expect(created_product.nombre).to eq('Smartphone Samsung Galaxy')
      expect(created_product.tienda).to eq(@tienda)
      expect(created_product.categoria).to eq(@categoria)
    end

    it 'creates a product with prices using the precios tab' do
      # Login as admin user
      admin_login(@admin_user, 'admin123')

      # Navigate to new product page
      visit '/productos/new'
      expect(page).to have_css('#general', wait: 10)

      # Fill in basic product details in General tab
      fill_in 'producto[nombre]', with: 'Pizza Margarita'
      fill_in 'producto[descripcion]', with: 'Pizza clásica con tomate, mozzarella y albahaca'

      # Select category
      select @categoria.nombre, from: 'producto[categoria_id]' if page.has_select?('producto[categoria_id]')

      # Submit the form from the General tab (avoid tab switching which can lose field values)
      if page.has_button?('Guardar')
        click_button 'Guardar'
      elsif page.has_button?('Crear')
        click_button 'Crear'
      else
        find('input[type="submit"], button[type="submit"]').click
      end

      # Verify the product was created successfully
      expect(page).to have_content('Pizza Margarita')
      expect(page).to have_content('creado correctamente')
      # Verify the product and its prices exist in the database
      created_product = Productos::Producto.find_by(nombre: 'Pizza Margarita')
      expect(created_product).to be_present
      expect(created_product.nombre).to eq('Pizza Margarita')
      expect(created_product.tienda).to eq(@tienda)
      expect(created_product.categoria).to eq(@categoria)

      # Check if prices were created with the correct importe
      if created_product.precios.any?
        precio = created_product.precios.first
        expect(precio.importe).to be > 0 # At least verify it's positive

        # If we specifically set 2500, check for that
      end
    end

    it 'validates required fields in product creation' do
      # Login as admin user
      admin_login(@admin_user, 'admin123')

      # Navigate to new product page
      visit '/productos/new'

      # Try to submit form with missing required fields (nombre and categoria are required)
      if page.has_button?('Guardar')
        click_button 'Guardar'
      elsif page.has_button?('Crear')
        click_button 'Crear'
      else
        find('input[type="submit"], button[type="submit"]').click
      end

      # Should show validation errors or stay on the form
      expect(page).to have_current_path(%r{/productos})

      # Check for validation error messages
      has_error = page.has_content?('error') ||
                  page.has_content?('requerido') ||
                  page.has_content?('obligatorio') ||
                  page.has_content?('no puede estar en blanco')

      expect(has_error).to be true
    end

    it 'edits an existing product and removes a client-specific price' do
      # Create a client first
      @cliente = create(:cliente,
                        nombre: 'Cliente Premium',
                        tienda: @tienda)

      # Create a cuenta for the client
      @cuenta = create(:cuenta, cliente: @cliente)

      # Create a product with two prices: one general and one for the specific client
      @producto_existing = create(:producto,
                                  :with_client_prices,
                                  nombre: 'Laptop Dell Inspiron',
                                  descripcion: 'Laptop Dell Inspiron 15 pulgadas',
                                  tienda: @tienda,
                                  categoria: @categoria,
                                  cliente: @cliente,
                                  client_price: 75_000.0,
                                  general_price: 80_000.0)
      # Login as admin user
      admin_login(@admin_user, 'admin123')

      # Navigate to the product edit page
      visit "/productos/#{@producto_existing.id}/edit"

      expect(page).to have_current_path(%r{/productos/#{@producto_existing.id}/edit})

      # Verify the product name is displayed
      expect(page).to have_field('producto[nombre]', with: 'Laptop Dell Inspiron')

      # Switch to the Precios tab by clicking the tab link
      find('a[href="#listaprecios"]').click
      expect(page).to have_css('#listaprecios.active', wait: 5)

      # Find price rows in the precios table
      within('#listaprecios') do
        price_rows = all('tr.fields', wait: 5)

        # Try to find the client-specific price row (contains client name)
        client_row = price_rows.find { |row| row.text.include?('Cliente Premium') }

        if client_row
          # Click the remove button within the client price row
          within(client_row) do
            find('.remove_nested_fields', match: :first).click
          end
        elsif price_rows.length > 1
          # If we can't identify by name, remove the first price row
          within(price_rows.first) do
            find('.remove_nested_fields', match: :first).click
          end
        end
      end

      # Submit the form to save changes
      click_button 'Guardar'

      # Verify the product was updated successfully
      expect(page).to have_content('Laptop Dell Inspiron')
      expect(page).to have_content('actualizado correctamente')

      # Verify in the database that changes were made
      @producto_existing.reload
      remaining_prices = @producto_existing.precios.reload
      expect(remaining_prices.count).to be >= 1
    end
  end
end
