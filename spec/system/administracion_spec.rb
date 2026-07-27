require 'rails_helper'

RSpec.describe 'Administración', :js, type: :system do
  before do
    @tienda = create(:tienda,
                     nombre: 'Admin Test Store',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'admin@test.com',
                     mensaje_bienvenida: 'Bienvenido',
                     venta_mostrador: true,
                     carrito_de_compras: true)

    @admin_user = create(:usuario, :admin,
                         login: 'admintest',
                         password: 'admin123',
                         password_confirmation: 'admin123',
                         nombre: 'Admin User',
                         email: 'admintest@example.com',
                         visualizando_tienda: @tienda)
    @admin_user.tiendas << @tienda unless @admin_user.tiendas.include?(@tienda)

    @cliente = create(:cliente, tienda: @tienda, nombre: 'Cliente Test')
    @cuenta = create(:cuenta, cliente: @cliente, nombre: 'Cuenta Test')

    @categoria = create(:categoria, nombre: 'Cat Admin', tienda: @tienda)
    @producto1 = create(:producto, nombre: 'Producto Alpha', tienda: @tienda, categoria: @categoria, codigo: 'PA01')
    @producto2 = create(:producto, nombre: 'Producto Beta', tienda: @tienda, categoria: @categoria, codigo: 'PB02')

    @tipo_factura = Comprobantes::Tipo.find_or_create_by!(codigo: 1) do |t|
      t.desc = 'Factura'
      t.clase = 'Ventas::Facturacion::Factura'
      t.letra = 'A'
      t.debitan = true
    end
    @tipo_nc = Comprobantes::Tipo.find_or_create_by!(codigo: 3) do |t|
      t.desc = 'Nota de Crédito'
      t.clase = 'Ventas::Facturacion::NotaCredito'
      t.letra = 'A'
      t.debitan = false
    end
    @tipo_recibo = Comprobantes::Tipo.find_or_create_by!(codigo: 4) do |t|
      t.desc = 'Recibo'
      t.clase = 'Cobros::Recibo'
      t.letra = 'X'
      t.debitan = false
    end
  end

  def login_admin
    visit root_path
    fill_in 'username', with: @admin_user.login
    fill_in 'password', with: 'admin123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10)
  end

  describe 'Ventas (Comprobantes)' do
    before do
      # Create a pedido for the factura (required by show view)
      # IMPORTANT: Must be estado_id >= 2 so the layout's _pedido_en_curso
      # doesn't pick it up and try to check can?(:aceptar, pedido) in the nav
      @pedido = create(:pedido, tienda: @tienda, cuenta: @cuenta, fecha: Date.current,
                                estado_id: 1, autor: @admin_user, usuario: @admin_user)
      ps1 = Productos::ProductoSolicitado.new(pedido: @pedido, producto: @producto1,
                                              cantidad: 2, precio_unitario: 300, precio_con_descuento: 300)
      ps1.save(validate: false)
      ps2 = Productos::ProductoSolicitado.new(pedido: @pedido, producto: @producto2,
                                              cantidad: 3, precio_unitario: 200, precio_con_descuento: 200)
      ps2.save(validate: false)
      @pedido.update_column(:estado_id, 3) # confirmado, so layout won't pick it up
      @pedido.update_column(:codigo, 'TEST001') # needed for pedido.to_s in views

      # Create a confirmed factura for today
      @factura = Ventas::Facturacion::Factura.new(
        tienda: @tienda, cuenta: @cuenta, pedido: @pedido, autor: @admin_user,
        fecha_emision: Time.current, completar_on_save: true,
        renglones: [
          { producto: @producto1, cantidad: 2, precio_unitario: 300, descripcion: 'Producto Alpha' },
          { producto: @producto2, cantidad: 3, precio_unitario: 200, descripcion: 'Producto Beta' }
        ]
      )
      @factura.save!
      @factura.update_column(:estado_id, 2)
      @factura.update_column(:nro, 1)
    end

    it 'shows facturas on the comprobantes index page' do
      login_admin
      visit '/comprobantes'

      expect(page).to have_css('#index-comprobantes', wait: 10)
      expect(page).to have_content('Ventas')

      # Factura should be listed
      expect(page).to have_css('#comprobantes')
      expect(page).to have_content(@factura.total.to_s)
    end

    it 'shows factura details on the show page' do
      login_admin
      visit comprobante_path(@factura)

      expect(page).to have_css('#show-comprobante', wait: 10)

      # Verify renglones
      expect(page).to have_content('Producto Alpha')
      expect(page).to have_content('Producto Beta')

      # Verify prices
      expect(page).to have_content('300')
      expect(page).to have_content('200')
    end

    context 'with cupon discount' do
      before do
        # Create NC linked to the factura (simulating cupon discount)
        @nota_credito = Ventas::Facturacion::NotaCredito.new(
          tienda: @tienda, cuenta: @cuenta, autor: @admin_user,
          fecha_emision: Time.current, completar_on_save: true,
          cancela_a: @factura,
          renglones: [
            { producto: @producto1, cantidad: 2, precio_unitario: 50, descripcion: 'Descuento cupón ABC - Producto Alpha' },
            { producto: @producto2, cantidad: 3, precio_unitario: 33.33, descripcion: 'Descuento cupón ABC - Producto Beta' }
          ]
        )
        @nota_credito.save!
        @nota_credito.update_column(:estado_id, 2)
        @nota_credito.update_column(:nro, 2)
      end

      it 'shows both factura and NC on comprobantes index' do
        login_admin
        visit '/comprobantes'

        expect(page).to have_css('#comprobantes', wait: 10)

        # Both comprobantes are listed (factura as RTOA/FCA, NC as NCA)
        within('#comprobantes') do
          expect(page).to have_content('$1.200,00')
          expect(page).to have_content('Confirmado', count: 2)
        end
      end

      it 'shows "Cancelado por" NC on factura show page' do
        # Create afectacion linking NC to factura
        Comprobantes::Afectacion.create!(
          comprobante: @nota_credito,
          afectado: @factura,
          importe: @nota_credito.total
        )

        login_admin
        visit comprobante_path(@factura)

        expect(page).to have_css('#show-comprobante', wait: 10)
        expect(page).to have_content('Cancelado por')
      end
    end
  end

  describe 'Cobros (Recibos)' do
    it 'displays the cobros index page' do
      login_admin
      visit '/cobros'

      expect(page).to have_css('#index-recibos', wait: 10)
      expect(page).to have_content('Cobros')
      expect(page).to have_link('Nuevo Recibo')
    end
  end

  describe 'Saldos' do
    it 'displays the saldos index page' do
      login_admin
      visit '/saldos'

      expect(page).to have_css('#index-saldos', wait: 10)
      expect(page).to have_content('Saldos')
    end
  end

  describe 'Cuentas Corrientes' do
    it 'displays the cuentas corrientes index page' do
      login_admin
      visit '/cuentas_corrientes'

      expect(page).to have_css('#index-ctasctes', wait: 10)
      expect(page).to have_content('Cuentas Corrientes')
    end
  end
end
