# frozen_string_literal: true

require 'rails_helper'

# Covers:
#   - Cliente destroys their own pending pedido from the index
#   - Cliente re-edits their own accepted pedido (resets to pendiente, go to edit form)
#   - Admin destroys an accepted pedido from the index
RSpec.describe 'Pedido lifecycle — destroy and re-edit', :js, type: :system do
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
                     nombre: 'Lifecycle Store',
                     dominio: 'localhost',
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    @cliente = create(:cliente,
                      nombre: 'Cliente Lifecycle',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: true,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta, nombre: 'Cuenta Lifecycle', cliente: @cliente)

    @user = create(:usuario, :cliente,
                   login: 'lifecycleuser',
                   password: 'password123',
                   password_confirmation: 'password123',
                   nombre: 'Lifecycle User',
                   email: 'lifecycle@example.com',
                   cuenta: @cuenta,
                   tienda_cliente: @tienda,
                   visualizando_tienda: @tienda)

    @categoria = create(:categoria,
                        nombre: 'Almuerzos LC',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria, nombre: 'Menu Dummy LC', tienda: @tienda, menu_diario: true)

    @cliente.categorias << @categoria

    @producto = create(:producto, nombre: 'Producto Lifecycle', tienda: @tienda, categoria: @categoria)
    create(:precio, producto: @producto, importe: 200.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def build_pedido(estado_id: 1)
    fecha = @cuenta.proximo_dia_pedido
    fecha += 1.day while fecha.saturday? || fecha.sunday?
    p = build(:pedido, tienda: @tienda, cuenta: @cuenta, estado_id: estado_id,
                       fecha: fecha, autor: @user, usuario: @user)
    p.asignar_cuenta_manual
    p.cuenta = @cuenta
    p.save!
    create(:producto_solicitado, pedido: p, producto: @producto, cantidad: 1, precio_unitario: 200.0)
    p
  end

  def login_cliente
    visit root_path
    fill_in 'username', with: 'lifecycleuser'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path(%r{/pedidos}, wait: 10)
  end

  # ─── DESTROY ──────────────────────────────────────────────────────────────────
  # NOTE: The pedidos index filters out pending pedidos (no_pendientes = true) by default.
  # Pending pedidos only appear in the cart dropdown (which is collapsed/hidden).
  # Accepted pedidos (estado=2) DO appear on the index and can be destroyed by the cliente
  # when fecha_permitida? is true and they are the author.

  context 'destroying an accepted pedido' do
    it 'cliente destroys their accepted pedido from the index — pedido disappears' do
      pedido = build_pedido(estado_id: 1)
      pedido.update_column(:estado_id, 2)
      pedido_id = pedido.id

      login_cliente
      visit pedidos_path

      # Accepted pedidos appear in the default index (no_pendientes only filters estado=1)
      trash_link = find("a[href='#{pedido_path(pedido)}'][data-method='delete']", wait: 10)
      page.accept_confirm do
        trash_link.click
      end

      expect(page).to have_current_path(pedidos_path, wait: 10)
      expect(page).to have_content(/eliminado|correctamente/i, wait: 5)
      expect(Pedidos::Pedido.exists?(pedido_id)).to be(false)
    end
  end

  # ─── RE-EDIT ──────────────────────────────────────────────────────────────────

  context 're-editing an accepted pedido' do
    it 'cliente re-edits their aceptado pedido — estado resets to pendiente and edit form opens' do
      # Create an accepted pedido (estado_id=2) bypassing callbacks
      pedido = build_pedido(estado_id: 1)
      pedido.update_column(:estado_id, 2)
      pedido.id

      login_cliente
      visit pedidos_path

      # The edit_pedido_link renders as a link to re_edit_pedido_path for non-pending pedidos
      re_edit_link = find("a[href='#{re_edit_pedido_path(pedido)}']", wait: 5)
      page.accept_confirm do
        re_edit_link.click
      end

      # Should be redirected to the edit form
      expect(page).to have_current_path(edit_pedido_path(pedido), wait: 10)

      # estado is back to 1 (pendiente)
      expect(pedido.reload.estado_id).to eq(1)
      expect(pedido.reload.pendiente?).to be(true)
    end
  end

  # ─── RE-EDIT from SHOW page ───────────────────────────────────────────────────

  context 're-editing from the show (comprar) page' do
    it 'Modificar pedido button on comprar page (for aceptado+CC) resets to pending' do
      pedido = build_pedido(estado_id: 1)
      pedido.update_column(:estado_id, 2)

      login_cliente

      # The show page renders _pedido.html.erb which shows the re_edit button when stock warning present
      # For direct access, visit the comprar path
      visit pedido_path(pedido)
      expect(page).to have_css('#show-pedido', wait: 10)

      # The header actions include "Modificar Pedido" (via edit_pedido_link)
      re_edit_link = find("a[href='#{re_edit_pedido_path(pedido)}']", wait: 5)
      page.accept_confirm do
        re_edit_link.click
      end

      expect(page).to have_current_path(edit_pedido_path(pedido), wait: 10)
      expect(pedido.reload.estado_id).to eq(1)
    end
  end
end
