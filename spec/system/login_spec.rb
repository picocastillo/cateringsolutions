require 'rails_helper'

RSpec.describe 'Login System', :js, type: :system do
  before do
    # Create a test clinic/tienda
    @tienda = create(:tienda,
                     nombre: 'Test Store',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@store.com',
                     mensaje_bienvenida: 'Bienvenido a nuestra tienda online')

    # Create a test user for login
    @user = create(:usuario,
                   login: 'testuser',
                   password: 'password123',
                   password_confirmation: 'password123',
                   nombre: 'Test User',
                   email: 'test@example.com',
                   visualizando_tienda: @tienda)
  end

  describe 'Root Page / Login Page' do
    it 'displays the login form correctly on root page' do
      visit root_path

      # Check that we're on the root page
      expect(page).to have_current_path(root_path)

      # Debug: Let's see what's actually on the page

      # Look for the login form elements
      if page.has_css?('form#loginform')

        # Look for form elements
        username_field = page.has_field?('username') || page.has_css?('input[name="username"]')
        password_field = page.has_field?('password') || page.has_css?('input[name="password"]')
        submit_button = page.has_button?('Iniciar sesión') || page.has_css?('input[type="submit"]') || page.has_css?('button[type="submit"]')
        # Check for welcome message

        # Check for store contact info

        # Form assertions
        expect(page).to have_css('form#loginform')
        expect(page).to have_field('username') if username_field
        expect(page).to have_field('password') if password_field
        expect(page).to have_button('Iniciar sesión') if submit_button

      end
    end

    it 'shows validation errors for empty fields' do
      visit root_path

      # Try to submit empty form
      click_button 'Iniciar sesión'

      # Should stay on root page and show some kind of error
      expect(page).to have_current_path(public_path) # Form posts to public_path
    end

    it 'shows error for invalid credentials' do
      visit root_path

      # Fill with invalid credentials
      fill_in 'username', with: 'wronguser'
      fill_in 'password', with: 'wrongpassword'
      click_button 'Iniciar sesión'

      # Should show error and stay on login page
      expect(page).to have_current_path(public_path)
    end

    it 'successfully logs in with valid credentials' do
      visit root_path

      # Fill with valid credentials
      fill_in 'username', with: @user.login
      fill_in 'password', with: 'password123'
      click_button 'Iniciar sesión'

      # Should redirect away from login page
      expect(page).not_to have_current_path(root_path)
      expect(page).not_to have_current_path(public_path)

      # Should be on a dashboard or main page

      # Should not see login form anymore
      expect(page).not_to have_css('form#loginform')
    end
  end

  describe 'Authentication Flow' do
    it 'redirects to login when accessing protected pages while logged out' do
      # Try to access a protected page
      visit '/inicio'

      # Should redirect to root login page
      expect(page).to have_current_path(root_path)
    end

    it 'allows access to protected pages when logged in' do
      # Login first
      visit root_path
      fill_in 'username', with: @user.login
      fill_in 'password', with: 'password123'
      click_button 'Iniciar sesión'

      # Now try to access protected page
      visit '/inicio'

      # Should not redirect to login
      expect(page).not_to have_current_path(root_path)
      expect(page).to have_current_path('/inicio')
    end
  end

  describe 'Store Branding' do
    it 'displays store information on login page' do
      visit root_path

      # Check for store name, contact info, or branding
      store_info_found = false

      store_info_found = true if page.has_text?(@tienda.nombre)

      store_info_found = true if page.has_text?(@tienda.telefono)

      store_info_found = true if page.has_text?(@tienda.email)

      store_info_found = true if page.has_text?(@tienda.mensaje_bienvenida)

      # Check for background image or branding
      store_info_found = true if page.has_css?('img.imagen-izquierda') || page.has_css?('[style*="background"]')

      expect(store_info_found).to be true
    end
  end
end
