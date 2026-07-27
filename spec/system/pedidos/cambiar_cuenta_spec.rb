# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pedidos Cambiar Cuenta', :js, type: :system do
  let(:tienda) do
    create(:tienda, nombre: 'CC Store', carrito_de_compras: true, venta_mostrador: true)
  end
  let(:admin) { create(:usuario, :admin, :with_password, visualizando_tienda: tienda) }

  let(:cliente1) { create(:cliente, tienda: tienda, nombre: 'Cliente Alpha') }
  let(:cuenta1) { create(:cuenta, cliente: cliente1, nombre: 'Cuenta Alpha') }
  let(:cliente2) { create(:cliente, tienda: tienda, nombre: 'Cliente Beta') }
  let(:cuenta2) { create(:cuenta, cliente: cliente2, nombre: 'Cuenta Beta') }

  let(:categoria) do
    create(:categoria, tienda: tienda, nombre: 'Alimentos', stock_activo: false, menu_diario: false)
  end

  let!(:producto) do
    create(:producto, tienda: tienda, categoria: categoria, nombre: 'Empanada de Carne')
  end

  before do
    admin.tiendas << tienda unless admin.tiendas.include?(tienda)

    # Associate categories with both clients (needed for product visibility)
    cliente1.categorias << categoria unless cliente1.categorias.include?(categoria)
    cliente2.categorias << categoria unless cliente2.categorias.include?(categoria)

    # Dummy menu diario category to avoid SQL errors
    create(:categoria, nombre: 'Menu Diario', tienda: tienda, menu_diario: true)

    # Prices for both clients
    create(:precio, :for_cliente, producto: producto, cliente: cliente1, importe: 100)
    create(:precio, :for_cliente, producto: producto, cliente: cliente2, importe: 150)
  end

  it 'changes cuenta and reloads products via AJAX' do
    pedido = Pedidos::Pedido.new(
      tienda: tienda, cuenta: cuenta1, fecha: Date.current,
      estado_id: 1, autor: admin, usuario: admin,
      pedido_para_empresa: true
    )
    pedido.save(validate: false)

    admin_login(admin, 'password123')
    visit edit_pedido_path(pedido)

    # Page should load with the pedido form and products
    expect(page).to have_css('#productos-en-venta', wait: 15)

    # Ensure tipo_pedido is "Cuenta" mode (value 2)
    page.execute_script("$('#pedido_tipo_pedido').val(2).trigger('change')")
    sleep 0.5

    # Change cuenta to cuenta2 via select2 (add option if not present, then trigger change)
    page.execute_script(<<~JS)
      var $el = $('#pedido_cuenta_id');
      if ($el.find('option[value="#{cuenta2.id}"]').length === 0) {
        $el.append(new Option('Cuenta Beta', #{cuenta2.id}));
      }
      $el.val(#{cuenta2.id}).trigger('change');
    JS

    # Wait for AJAX cambiar_cuenta response to complete
    wait_for_ajax

    # Products section should be present (reloaded by cambiar_cuenta.js.erb)
    expect(page).to have_css('#productos-en-venta', wait: 10)
  end
end
