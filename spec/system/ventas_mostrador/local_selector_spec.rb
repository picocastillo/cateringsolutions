# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ventas Mostrador - Local Selector', :js, type: :system do
  before do
    Comprobantes::Tipo.find_or_create_by(codigo: 1) do |tipo|
      tipo.desc = 'Factura'
      tipo.clase = 'Ventas::Facturacion::Factura'
      tipo.letra = 'A'
      tipo.debitan = false
    end
  end

  def setup_tienda(multiple_locales:)
    @tienda = create(:tienda,
                     nombre: 'Tienda Local Test',
                     dominio: 'localhost',
                     telefono: '123456789',
                     email: 'localtest@test.com',
                     venta_mostrador: true,
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false,
                     multiple_locales: multiple_locales)

    @cliente_cf = create(:cliente,
                         nombre: 'Consumidor Final',
                         tienda: @tienda,
                         dia_inicio_ciclo_facturacion: 1,
                         vencimiento_a: 30,
                         horarios_de_entrega: false,
                         usuario_puede_elegir_cuenta: false,
                         permitir_envios_a_domicilio: false,
                         cuenta_corriente: true,
                         listas_de_precio_privada: false)

    @cuenta_cf = @cliente_cf.cuentas.first || create(:cuenta,
                                                     nombre: 'Consumidor Final',
                                                     cliente: @cliente_cf)

    @categoria = create(:categoria,
                        nombre: 'Productos Local Test',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria,
           nombre: 'Menu Diario Dummy',
           tienda: @tienda,
           menu_diario: true)

    @cliente_cf.categorias << @categoria unless @cliente_cf.categorias.include?(@categoria)

    @producto = create(:producto,
                       nombre: 'Prod Local Test',
                       codigo: 'LOCTEST01',
                       tienda: @tienda,
                       categoria: @categoria,
                       discontinued_at: nil)

    create(:precio, producto: @producto, importe: 100.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def create_admin(login:, local: nil)
    admin = create(:usuario, :admin,
                   login: login,
                   password: 'password123',
                   password_confirmation: 'password123',
                   nombre: "Admin #{login}",
                   email: "#{login}@example.com",
                   visualizando_tienda: @tienda,
                   local: local)
    admin.tiendas << @tienda unless admin.tiendas.include?(@tienda)
    admin
  end

  def login_and_visit_vm(login)
    visit root_path
    fill_in 'username', with: login
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)
    visit ventas_mostrador_pedidos_path
    expect(page).to have_content('Venta Mostrador', wait: 10)
    expect(page).to have_css('#agregar-producto-vr', wait: 10)
  end

  # ─── Multi-local tienda: admin with local assigned ──────────────

  context 'multi-local tienda, admin with one local assigned' do
    before do
      setup_tienda(multiple_locales: true)
      @local1 = create(:local, nombre: 'Sucursal Centro', tienda: @tienda)
      @local2 = create(:local, nombre: 'Sucursal Norte', tienda: @tienda)
      @admin = create_admin(login: 'adm_multilocal', local: @local1)
    end

    scenario 'shows local selector with all tienda locales' do
      login_and_visit_vm('adm_multilocal')

      expect(page).to have_css('.vm-local-select', wait: 5)
      within('.vm-local-select') do
        expect(page).to have_select('pedido[local_id]')
        options = all('select option').map(&:text)
        expect(options).to include('Sucursal Centro')
        expect(options).to include('Sucursal Norte')
      end
    end

    scenario 'pedido defaults to admin local_activo' do
      login_and_visit_vm('adm_multilocal')

      expect(page).to have_css('.vm-local-select', wait: 5)
      pedido = Pedidos::Pedido.where(autor: @admin, venta_mostrador: true).last
      expect(pedido.local).to eq(@local1)
    end

    scenario 'selector pre-selects admin local' do
      login_and_visit_vm('adm_multilocal')

      within('.vm-local-select') do
        expect(page).to have_select('pedido[local_id]', selected: 'Sucursal Centro')
      end
    end

    scenario 'admin can change local via dropdown' do
      login_and_visit_vm('adm_multilocal')

      within('.vm-local-select') do
        select 'Sucursal Norte', from: 'pedido[local_id]'
      end

      # Add a product to trigger a save with the new local
      fill_in 'codigo', with: 'LOCTEST01'
      find('#codigo').native.send_keys(:return)
      expect(page).to have_content('Prod Local Test', wait: 5)
    end
  end

  # ─── Single-local tienda: no selector shown ────────────────────

  context 'single-local tienda (multiple_locales: false)' do
    before do
      setup_tienda(multiple_locales: false)
      @local = create(:local, nombre: 'Unica Sucursal', tienda: @tienda)
      @admin = create_admin(login: 'adm_single', local: @local)
    end

    scenario 'does not show local selector' do
      login_and_visit_vm('adm_single')

      expect(page).not_to have_css('.vm-local-select')
    end

    scenario 'pedido is auto-assigned the only local' do
      login_and_visit_vm('adm_single')

      pedido = Pedidos::Pedido.where(autor: @admin, venta_mostrador: true).last
      expect(pedido.local).to eq(@local)
    end
  end
end
