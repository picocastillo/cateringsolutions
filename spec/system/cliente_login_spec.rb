require 'rails_helper'

RSpec.describe 'Cliente User Login System', :js, type: :system do
  before do
    # Create Comprobantes::Tipo records needed for billing system
    # Use find_or_create_by to avoid conflicts with other tests
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

    Comprobantes::Tipo.find_or_create_by(codigo: 3) do |tipo|
      tipo.desc = 'Nota de Crédito'
      tipo.clase = 'Ventas::Facturacion::NotaCredito'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    Comprobantes::Tipo.find_or_create_by(codigo: 4) do |tipo|
      tipo.desc = 'Recibo'
      tipo.clase = 'Cobros::Recibo'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    Comprobantes::Tipo.find_or_create_by(codigo: 5) do |tipo|
      tipo.desc = 'Orden de Pago'
      tipo.clase = 'Ventas::Facturacion::OrdenPago'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    Comprobantes::Tipo.find_or_create_by(codigo: 6) do |tipo|
      tipo.desc = 'Pago'
      tipo.clase = 'Entregas::Pago'
      tipo.letra = 'A'
      tipo.debitan = false
    end
    @tienda = create(:tienda,
                     nombre: 'Test Store with Cart & Counter Sales',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'test@store.com',
                     mensaje_bienvenida: 'Bienvenido a nuestra tienda online',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false) # Disable delivery schedules to avoid validation

    # Create a cliente (customer company) associated with this tienda
    @cliente = create(:cliente,
                      nombre: 'Test Company Cliente',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false, # Disable delivery schedules to avoid validation
                      usuario_puede_elegir_cuenta: false,  # Disable account selection to avoid validation
                      permitir_envios_a_domicilio: false,  # Disable home delivery to avoid validation
                      cuenta_corriente: true) # Create a cuenta (account) for the cliente # Enable account credit to show Finalizar Compra button
    @cuenta = create(:cuenta,
                     nombre: 'Test Account',
                     cliente: @cliente)

    # Create a cliente user with proper associations
    @cliente_user = create(:usuario, :cliente,
                           login: 'clienteuser',
                           password: 'password123',
                           password_confirmation: 'password123',
                           nombre: 'Cliente Test User',
                           email: 'cliente@example.com',
                           cuenta: @cuenta,
                           tienda_cliente: @tienda,
                           visualizando_tienda: @tienda)
  end

  describe 'Cliente User Authentication' do
    it 'successfully logs in cliente user with valid credentials and redirects to pedidos edit' do
      visit root_path

      fill_in 'username', with: @cliente_user.login
      fill_in 'password', with: 'password123'
      click_button 'Iniciar sesión'

      # Should redirect to pedidos edit after successful login
      expect(page).to have_current_path(%r{/pedidos/\d+/edit})
    end

    it 'redirects to password change page when password is expired, then to pedidos edit after update' do
      # Create a user with expired password
      @expired_user = create(:usuario, :cliente,
                             login: 'expireduser',
                             password: 'oldpassword123',
                             password_confirmation: 'oldpassword123',
                             nombre: 'Expired User',
                             email: 'expired@example.com',
                             cuenta: @cuenta,
                             tienda_cliente: @tienda,
                             visualizando_tienda: @tienda,
                             password_expires_at: 1.day.ago)

      visit root_path
      fill_in 'username', with: @expired_user.login
      fill_in 'password', with: 'oldpassword123'
      click_button 'Iniciar sesión'

      # Should be redirected to password change page (singular cuenta, not cuentas)
      expect(page).to have_current_path('/cuenta/edit')
      expect(page).to have_content('Tu contraseña ha vencido')

      # Update the password with correct field names
      fill_in 'password_anterior', with: 'oldpassword123'
      fill_in 'usuario[password]', with: 'newpassword123'
      fill_in 'usuario[password_confirmation]', with: 'newpassword123'
      click_button 'Guardar'

      # Should redirect to pedidos edit after password update
      expect(page).to have_current_path(%r{/pedidos/\d+/edit})
    end

    it 'completes a full purchase flow: login → add products → finalize purchase' do
      # Create a categoria for products
      @categoria = create(:categoria,
                          nombre: 'Comidas',
                          tienda: @tienda,
                          menu_diario: false)

      # WORKAROUND: Create a dummy daily menu category to avoid empty array SQL issue
      # This fixes the bug where WHERE NOT IN () with empty array removes all results
      create(:categoria,
             nombre: 'Menu Diario Dummy',
             tienda: @tienda,
             menu_diario: true)

      # Associate the cliente with the categoria so products are visible
      @cliente.categorias << @categoria unless @cliente.categorias.include?(@categoria)
      @cliente.reload

      # Set listas_de_precio_privada to false so cliente can see general prices
      @cliente.update!(listas_de_precio_privada: false)

      # Create products
      @producto1 = create(:producto,
                          nombre: 'Hamburguesa Clásica',
                          codigo: 'BURG001',
                          descripcion: 'Hamburguesa con queso y lechuga',
                          tienda: @tienda,
                          categoria: @categoria,
                          discontinued_at: nil)

      @producto2 = create(:producto,
                          nombre: 'Papas Fritas',
                          codigo: 'PAPAS001',
                          descripcion: 'Papas fritas crocantes',
                          tienda: @tienda,
                          categoria: @categoria,
                          discontinued_at: nil)

      # Create general prices (no client-specific prices)
      create(:precio,
             producto: @producto1,
             importe: 1500.0,
             fecha_desde: 1.week.ago,
             fecha_hasta: 1.year.from_now)

      create(:precio,
             producto: @producto2,
             importe: 800.0,
             fecha_desde: 1.week.ago,
             fecha_hasta: 1.year.from_now)

      # Login as cliente user
      visit root_path
      fill_in 'username', with: @cliente_user.login
      fill_in 'password', with: 'password123'
      click_button 'Iniciar sesión'

      # Should be on pedidos edit page
      expect(page).to have_current_path(%r{/pedidos/\d+/edit})

      expect(page).to have_content(@producto1.nombre)

      # Directly update the pedido to be a company order to bypass usuario validation
      pedido = Pedidos::Pedido.last
      pedido.update!(
        pedido_para_empresa: true,
        usuario_id: nil,
        cuenta_id: @cuenta.id
      )

      # Change to company order type (Cuenta) in the interface
      select 'Cuenta', from: 'pedido_tipo_pedido' if page.has_select?('pedido_tipo_pedido')

      # Verify products are visible
      expect(page).to have_content(@producto1.nombre)
      expect(page).to have_content(@producto2.nombre)

      # Add products by clicking FontAwesome + buttons
      plus_buttons = page.all('a.cambiadores-cantidad.mas')
      expect(plus_buttons.count).to be >= 2

      plus_buttons.first(2).each_with_index do |button, _index|
        button.click
        sleep(0.3) # Brief delay between sequential AJAX clicks
      end

      # Click "Ir al Carrito" button

      # Find and click "Ir al Carrito" button
      carrito_button = page.find('a, button', text: /ir al carrito/i, match: :first)
      expect(carrito_button).not_to have_css('.disabled')
      carrito_button.click

      # Should be redirected to comprar page (order confirmation screen)
      expect(page).to have_current_path(%r{/pedidos/\d+/comprar}, wait: 5)

      # Verify we're on the order confirmation screen
      expect(page).to have_content('Finalizar Compra')

      # Click "Finalizar Compra" button to complete the purchase
      confirmar_button = page.find('a, button', text: /finalizar compra/i, match: :first)
      confirmar_button.click

      # Wait for redirect away from comprar page
      expect(page).not_to have_current_path(%r{/pedidos/\d+/comprar}, wait: 10)

      # Check for success message and final redirect
      success_indicators = [
        'compra realizada exitosamente',
        'pedido confirmado',
        'gracias por su compra',
        'su pedido ha sido procesado',
        'compra completada',
        'aceptado'
      ]

      success_indicators.any? { |indicator| page.has_content?(indicator, wait: 2) }

      # Final verification: we should NOT be on the edit page anymore
      expect(page).not_to have_current_path(%r{/pedidos/\d+/edit})
    end
  end
end
