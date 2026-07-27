require 'rails_helper'

RSpec.describe 'Admin edits usuario password', :js, type: :system do
  before do
    # Ensure needed tipos comprobantes exist (mirrors other system specs setup)
    Comprobantes::Tipo.find_or_create_by(codigo: 1) do |tipo|
      tipo.desc = 'Factura'
      tipo.clase = 'Ventas::Facturacion::Factura'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    Comprobantes::Tipo.find_or_create_by(codigo: 2) do |tipo|
      tipo.desc = 'Nota de Débito'
      tipo.clase = 'Ventas::Facturacion::NotaDebito'
      tipo.letra = 'A'
      tipo.debitan = true
    end

    # Create necessary roles
    Usuarios::Rol.find_or_create_by(nombre: 'robot') do |rol|
      rol.descripcion = 'Robot role for testing'
      rol.modulo = 'Sistema'
    end

    Usuarios::Rol.find_or_create_by(nombre: 'comprador') do |rol|
      rol.descripcion = 'Comprador role for testing'
      rol.modulo = 'Pedidos'
    end

    Usuarios::Rol.find_or_create_by(nombre: 'administrador_empresa') do |rol|
      rol.descripcion = 'Administrador de empresa'
      rol.modulo = 'Usuarios'
    end

    Usuarios::Rol.find_or_create_by(nombre: 'admin') do |rol|
      rol.descripcion = 'Administrador'
      rol.modulo = 'Sistema'
    end
    @tienda = create(:tienda,
                     nombre: 'Test Store',
                     dominio: 'localhost',
                     venta_mostrador: true,
                     carrito_de_compras: true)

    # Create a cliente with cuenta in the same tienda
    @cliente = create(:cliente, tienda: @tienda)
    @cuenta = create(:cuenta, cliente: @cliente)

    # Create admin user (tipo_usuario_id: 2, no cuenta_id - internal staff)
    @admin = create(:usuario,
                    login: 'admin',
                    password: 'password123',
                    password_confirmation: 'password123',
                    nombre: 'Admin User',
                    email: 'admin@example.com',
                    visualizando_tienda: @tienda,
                    tipo_usuario_id: 2) # Admin type

    # Assign admin role to ensure access
    admin_role = Usuarios::Rol.find_or_create_by(nombre: 'admin')
    @admin.roles << admin_role unless @admin.roles.include?(admin_role)
    @admin.reload

    # Create cliente user with cuenta (tipo_usuario_id: 1)
    @target_user = create(:usuario,
                          login: 'clientuser',
                          password: 'oldpassword123',
                          password_confirmation: 'oldpassword123',
                          nombre: 'Cliente User',
                          email: 'client@example.com',
                          tipo_usuario_id: 1,
                          cuenta: @cuenta,
                          tienda_cliente: @tienda,
                          visualizando_tienda: @tienda)
  end

  it 'admin updates cliente usuario password and logs in with new credentials' do
    # Step 1: Login as admin
    admin_login(@admin, 'password123')

    # Step 2: Navigate to usuarios list
    visit usuarios_path
    expect(page).to have_current_path(usuarios_path)

    # Step 3: Find the client user in the table and click edit icon
    within(:xpath, "//tr[contains(., '#{@target_user.nombre}')]") do
      # The edit link is an icon, not text
      find('a[href*="edit"]').click
    end

    expect(page).to have_current_path(edit_usuario_path(@target_user))

    # Step 4: Change the password (keep the same login)
    new_password = 'NewPassword123!'

    fill_in 'usuario[password]', with: new_password
    fill_in 'usuario[password_confirmation]', with: new_password

    click_button 'Guardar'

    # Step 5: Logout as admin
    Capybara.reset_sessions!

    # Step 6: Login as client user with NEW password
    visit root_path
    expect(page).to have_current_path(root_path)

    fill_in 'username', with: @target_user.login
    fill_in 'password', with: new_password
    click_button 'Iniciar sesión'

    # Should successfully login and redirect away from login page
    expect(page).not_to have_current_path(root_path, wait: 10)
    expect(page).not_to have_current_path('/public')

    # Should not see login form anymore
    expect(page).not_to have_css('form#loginform')
  end
end
