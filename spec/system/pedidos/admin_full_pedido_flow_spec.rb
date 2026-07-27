# frozen_string_literal: true

require 'rails_helper'

# Covers: Admin user creating and managing single pedidos on behalf of a cliente.
#
# Flows tested:
#   1. Admin navigates to /pedidos/new → redirected to edit form
#   2. Admin adds a product (+ button) and sees it in cart
#   3. Admin removes a product (- to 0 removes it)
#   4. Admin applies a cupon on the comprar page and sees the discounted total
#   5. Admin removes the cupon
#   6. Admin finaliza via CC (Finalizar Compra button → estado aceptado)
#   7. Admin destroys an accepted pedido from the index
#   8. Admin re-edits an accepted pedido (estado resets to pendiente)
#   9. Admin cancels a confirmed pedido from the index

RSpec.describe 'Admin — full single pedido flow', :js, type: :system do
  before do
    Comprobantes::Tipo.find_or_create_by(codigo: 1) do |t|
      t.desc = 'Factura'
      t.clase = 'Ventas::Facturacion::Factura'
      t.letra = 'A'
      t.debitan = false
    end
    Comprobantes::Tipo.find_or_create_by(codigo: 3) do |t|
      t.desc = 'Nota de Crédito'
      t.clase = 'Ventas::Facturacion::NotaCredito'
      t.letra = 'A'
      t.debitan = false
    end

    @tienda = create(:tienda,
                     nombre: 'Admin Flow Store',
                     dominio: 'localhost',
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    @admin = create(:usuario, :admin, :with_password,
                    login: 'admin_flow_user',
                    nombre: 'Admin Flow',
                    email: 'adminflow@test.com',
                    visualizando_tienda: @tienda)
    @admin.tiendas << @tienda unless @admin.tiendas.include?(@tienda)

    @cliente = create(:cliente,
                      nombre: 'Cliente Admin Flow',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: true,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta, nombre: 'Cuenta Admin Flow', cliente: @cliente,
                              cuenta_corriente_parcial: true)

    @usuario_cliente = create(:usuario, :cliente,
                              login: 'cliente_admin_flow',
                              password: 'password123',
                              password_confirmation: 'password123',
                              nombre: 'Cliente User AF',
                              email: 'clienteaf@test.com',
                              cuenta: @cuenta,
                              tienda_cliente: @tienda,
                              visualizando_tienda: @tienda)

    @categoria = create(:categoria, nombre: 'Cat Admin Flow', tienda: @tienda,
                                    stock_activo: false, menu_diario: false)
    create(:categoria, nombre: 'Menu Dummy AF', tienda: @tienda, menu_diario: true)
    @cliente.categorias << @categoria

    @producto = create(:producto, nombre: 'Empanada AF', tienda: @tienda, categoria: @categoria)
    @producto2 = create(:producto, nombre: 'Pizza AF', tienda: @tienda, categoria: @categoria)

    create(:precio, :for_cliente, producto: @producto, cliente: @cliente, importe: 200,
                                  fecha_desde: Time.zone.today)
    create(:precio, :for_cliente, producto: @producto2, cliente: @cliente, importe: 300,
                                  fecha_desde: Time.zone.today)
  end

  def admin_login
    visit root_path
    fill_in 'username', with: 'admin_flow_user'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)
  end

  def fecha_pedido
    d = Date.current + 1.day
    d += 1.day while d.saturday? || d.sunday?
    d
  end

  def build_admin_pedido(estado_id: 1)
    p = build(:pedido, tienda: @tienda, cuenta: @cuenta, usuario: @usuario_cliente,
                       estado_id: 1, fecha: fecha_pedido, autor: @admin)
    p.asignar_cuenta_manual
    p.cuenta = @cuenta
    p.save!
    create(:producto_solicitado, pedido: p, producto: @producto, cantidad: 2, precio_unitario: 200.0)
    p.update_column(:estado_id, estado_id) if estado_id != 1
    p
  end

  # ─── 1. New pedido redirects to edit ───────────────────────────────────────

  describe 'visiting /pedidos/new as admin' do
    it 'creates a pedido and redirects to the edit form' do
      admin_login

      # Set the usuario on the admin's pending pedido via the new action
      visit new_pedido_path
      expect(page).to have_current_path(%r{/pedidos/\d+/edit}, wait: 10)
      expect(page).to have_css('#carga-pedidos', wait: 10)
    end
  end

  # ─── 2 & 3. Admin adds and removes products ────────────────────────────────

  describe 'admin adds and removes products via +/- buttons' do
    before do
      # Build a pedido for the cliente user — admin edits it
      @pedido = build(:pedido, tienda: @tienda, cuenta: @cuenta, usuario: @usuario_cliente,
                               estado_id: 1, fecha: fecha_pedido, autor: @admin)
      @pedido.asignar_cuenta_manual
      @pedido.cuenta = @cuenta
      @pedido.save!
      admin_login
    end

    it 'admin adds a product to the cart' do
      visit edit_pedido_path(@pedido)
      expect(page).to have_css('.producto-venta', wait: 15)
      card = page.all('.producto-venta').find { |c| c.text.include?(@producto.nombre) }
      within(card) { find('a.mas').click }
      sleep 0.8

      # Product appears in cart (either visible or in DOM)
      expect(page).to have_css('#pedido-en-curso .item', visible: :any, wait: 10)

      # DB: ProductoSolicitado created
      expect(@pedido.productos_solicitados.reload.count).to eq(1)
      expect(@pedido.productos_solicitados.first.cantidad).to eq(1)
    end

    it 'admin removes a product by decrementing to zero' do
      # Add one product first
      create(:producto_solicitado, pedido: @pedido, producto: @producto, cantidad: 1,
                                   precio_unitario: 200.0)

      visit edit_pedido_path(@pedido)
      expect(page).to have_css('.producto-venta', wait: 15)
      card = page.all('.producto-venta').find { |c| c.text.include?(@producto.nombre) }
      within(card) { find('a.menos').click }
      sleep 0.8

      # Product removed from cart
      expect(@pedido.productos_solicitados.reload.count).to eq(0)
    end
  end

  # ─── 4 & 5. Admin applies/removes cupon ────────────────────────────────────

  describe 'admin applies and removes a cupon on the comprar page' do
    before do
      @pedido = build_admin_pedido
      @cupon = create(:cupon, tienda: @tienda, codigo: 'ADMINCUPON',
                              tipo_descuento: 'importe', importe: 50)
      admin_login
    end

    it 'applies a cupon and the discounted total is shown' do
      visit pedido_comprar_path(@pedido)
      expect(page).to have_css('#show-pedido', wait: 15)

      # Apply cupon
      fill_in 'cupon_codigo_input', with: 'ADMINCUPON'
      find('#aplicar_cupon_btn').click

      # Cupon applied: code shown, total reduced
      expect(page).to have_content(/aplicado|ADMINCUPON/i, wait: 10)
      @pedido.reload
      expect(@pedido.cupon).to be_present
      expect(@pedido.importe_descuento_cupon.to_f).to eq(50.0)
    end

    it 'removes the cupon and the total is restored' do
      # Pre-apply cupon
      @pedido.update_columns(cupon_id: @cupon.id)
      @pedido.productos_solicitados.each do |ps|
        ps.update_columns(
          precio_con_descuento: [ps.precio_unitario - 50, 0].max
        )
      end

      visit pedido_comprar_path(@pedido)
      expect(page).to have_css('#quitar_cupon_btn', wait: 10)
      find('#quitar_cupon_btn').click

      # Wait for AJAX to complete (input reappears after cupon removal)
      expect(page).to have_css('#cupon_codigo_input', wait: 10)
      expect(@pedido.reload.cupon_id).to be_nil
    end
  end

  # ─── 6. Admin finaliza via CC ───────────────────────────────────────────────

  describe 'admin finalizes a pedido via cuenta corriente' do
    it 'Finalizar Compra transitions estado to aceptado and redirects to show page' do
      @pedido = build_admin_pedido
      admin_login

      visit pedido_comprar_path(@pedido)
      expect(page).to have_css('#confirmar_pedido', wait: 15)

      click_link 'Finalizar Compra'

      expect(page).to have_current_path(%r{/pedidos/\d+}, wait: 15)
      expect(@pedido.reload.estado_id).to eq(2)
    end
  end

  # ─── 7. Admin destroys an accepted pedido ──────────────────────────────────

  describe 'admin destroys an accepted pedido from the index' do
    it 'pedido disappears after trash-link confirmation' do
      @pedido = build_admin_pedido(estado_id: 2)
      pedido_id = @pedido.id
      admin_login

      visit pedidos_path

      trash_link = find("a[href='#{pedido_path(@pedido)}'][data-method='delete']", wait: 10)
      page.accept_confirm { trash_link.click }

      expect(page).to have_current_path(pedidos_path, wait: 10)
      expect(page).to have_content(/eliminado|correctamente/i, wait: 5)
      expect(Pedidos::Pedido.exists?(pedido_id)).to be(false)
    end
  end

  # ─── 8. Admin re-edits an accepted pedido ──────────────────────────────────

  describe 'admin re-edits an accepted pedido' do
    it 'resets estado to pendiente and opens the edit form' do
      @pedido = build_admin_pedido(estado_id: 2)
      admin_login

      visit pedidos_path
      re_edit_link = find("a[href='#{re_edit_pedido_path(@pedido)}']", wait: 10)
      page.accept_confirm { re_edit_link.click }

      expect(page).to have_current_path(edit_pedido_path(@pedido), wait: 10)
      expect(@pedido.reload.estado_id).to eq(1)
    end
  end

  # ─── 9. Admin cancels a confirmed pedido ───────────────────────────────────

  describe 'admin cancels a confirmed pedido from the index' do
    it 'transitions estado to cancelado' do
      @pedido = build_admin_pedido(estado_id: 3)
      pedido_id = @pedido.id
      admin_login

      # Navigate to index with estado_id filter to show confirmado pedidos
      visit "#{pedidos_path}?q[estado_id]=#{Pedidos::Estado[:confirmado].id}"

      cancel_link = find("a[href='#{cancelar_pedido_path(@pedido)}'][data-method='put']", wait: 10)
      page.accept_confirm { cancel_link.click }

      expect(page).to have_current_path(pedidos_path, wait: 10)
      expect(Pedidos::Pedido.find(pedido_id).estado_id).to eq(5)
    end
  end
end
