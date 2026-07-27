# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Vista productos toggle (pasadores / lista)', :js, type: :system do
  before do
    @tienda = create(:tienda,
                     nombre: 'Vista Toggle Store',
                     dominio: 'localhost',
                     carrito_de_compras: true,
                     horarios_de_entrega: false,
                     maneja_stock: false)

    @cliente = create(:cliente,
                      nombre: 'Cliente Vista Toggle',
                      tienda: @tienda,
                      dia_inicio_ciclo_facturacion: 1,
                      vencimiento_a: 30,
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: true,
                      listas_de_precio_privada: false)

    @cuenta = create(:cuenta, nombre: 'Cuenta Vista Toggle', cliente: @cliente)

    @user = create(:usuario, :cliente,
                   login: 'uservista',
                   password: 'password123',
                   password_confirmation: 'password123',
                   nombre: 'Vista Toggle User',
                   email: 'vista@example.com',
                   cuenta: @cuenta,
                   tienda_cliente: @tienda,
                   visualizando_tienda: @tienda)

    @categoria = create(:categoria,
                        nombre: 'Platos',
                        tienda: @tienda,
                        stock_activo: false,
                        menu_diario: false)

    create(:categoria, nombre: 'Menu Dummy', tienda: @tienda, menu_diario: true)
    @cliente.categorias << @categoria

    @producto = create(:producto, nombre: 'Milanesa Napo', tienda: @tienda, categoria: @categoria)
    create(:precio, producto: @producto, importe: 500.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  def login
    visit root_path
    fill_in 'username', with: 'uservista'
    fill_in 'password', with: 'password123'
    click_button 'Iniciar sesión'
    expect(page).to have_current_path(%r{/pedidos}, wait: 10)
  end

  scenario 'defaults to lista view' do
    login
    expect(page).to have_css('.producto-venta', wait: 10)
    expect(page).to have_css('.vista-productos-toggle [data-vista="lista"].active')
    expect(page).to have_css('.productos-lista-grid')
  end

  scenario 'switching to lista swaps the layout and persists the preference' do
    login
    expect(page).to have_css('.producto-venta', wait: 10)

    find('.vista-productos-toggle [data-vista="lista"]').click

    expect(page).to have_css('.productos-lista-grid', wait: 10)
    expect(page).to have_css('.producto-venta.producto-venta-lista', minimum: 1)
    expect(@user.reload.vista_productos).to eq 'lista'

    # Adding a product still works in lista mode (JS handlers delegated globally)
    within(page.all('.producto-venta-lista').find { |c| c.text.include?(@producto.nombre) }) do
      find('a.mas').click
    end
    sleep 0.8
    expect(page.find("#input_cantidad_#{@producto.id}").value.to_i).to eq(1)

    ps = Pedidos::Pedido.last.productos_solicitados.find_by(producto_id: @producto.id)
    expect(ps).not_to be_nil
    expect(ps.cantidad).to eq(1)
  end

  scenario 'switching back to pasadores re-renders swiper' do
    @user.update_column(:vista_productos, 'lista')
    login
    expect(page).to have_css('.productos-lista-grid', wait: 10)

    find('.vista-productos-toggle [data-vista="pasadores"]').click

    expect(page).to have_css('.swiper', wait: 10)
    expect(page).not_to have_css('.productos-lista-grid')
    expect(@user.reload.vista_productos).to eq 'pasadores'
  end
end
