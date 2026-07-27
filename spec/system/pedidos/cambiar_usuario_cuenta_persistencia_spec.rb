# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pedidos Cambiar Usuario/Cuenta Persistencia', :js, type: :system do
  let(:tienda) do
    create(:tienda,
           nombre: 'Persist Store',
           carrito_de_compras: true,
           venta_mostrador: true,
           horarios_de_entrega: false,
           maneja_stock: false)
  end

  let(:admin) { create(:usuario, :admin, :with_password, visualizando_tienda: tienda) }

  let(:cliente1) { create(:cliente, tienda: tienda, nombre: 'Cliente Alpha', cuenta_corriente: true, horarios_de_entrega: false, usuario_puede_elegir_cuenta: false, permitir_envios_a_domicilio: false) }
  let(:cuenta1) { create(:cuenta, cliente: cliente1, nombre: 'Cuenta Alpha') }
  let(:cliente2) { create(:cliente, tienda: tienda, nombre: 'Cliente Beta', cuenta_corriente: true, horarios_de_entrega: false, usuario_puede_elegir_cuenta: false, permitir_envios_a_domicilio: false) }
  let(:cuenta2) { create(:cuenta, cliente: cliente2, nombre: 'Cuenta Beta') }

  let(:usuario1) do
    create(:usuario, :cliente,
           login: 'user_alpha',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'User Alpha',
           email: 'alpha@test.com',
           cuenta: cuenta1,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let(:usuario2) do
    create(:usuario, :cliente,
           login: 'user_beta',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'User Beta',
           email: 'beta@test.com',
           cuenta: cuenta2,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let(:categoria) do
    create(:categoria, tienda: tienda, nombre: 'Alimentos', stock_activo: false, menu_diario: false)
  end

  let!(:producto) do
    create(:producto, tienda: tienda, categoria: categoria, nombre: 'Empanada Test')
  end

  before do
    admin.tiendas << tienda unless admin.tiendas.include?(tienda)

    # Associate categories with both clients
    cliente1.categorias << categoria unless cliente1.categorias.include?(categoria)
    cliente2.categorias << categoria unless cliente2.categorias.include?(categoria)

    # Dummy menu diario category
    create(:categoria, nombre: 'Menu Diario', tienda: tienda, menu_diario: true)

    # Prices for both clients
    create(:precio, :for_cliente, producto: producto, cliente: cliente1, importe: 100)
    create(:precio, :for_cliente, producto: producto, cliente: cliente2, importe: 150)

    # Ensure Comprobantes::Tipo exists for factura creation
    Comprobantes::Tipo.find_or_create_by!(codigo: 1) do |t|
      t.desc = 'Factura'
      t.clase = 'Ventas::Facturacion::Factura'
      t.letra = 'A'
      t.debitan = true
    end

    # Ensure usuarios are created (lazy-loaded lets)
    usuario1
    usuario2
  end

  describe 'changing cuenta persists through finalizar' do
    it 'updates pedido cuenta when admin changes cuenta and finalizes' do
      # Create pedido for cuenta1 (empresa mode)
      pedido = Pedidos::Pedido.new(
        tienda: tienda, cuenta: cuenta1, fecha: Date.current,
        estado_id: 1, autor: admin, usuario: admin,
        pedido_para_empresa: true
      )
      pedido.save(validate: false)

      admin_login(admin, 'password123')
      visit edit_pedido_path(pedido)

      expect(page).to have_css('#productos-en-venta', wait: 15)

      # Ensure tipo_pedido is "Cuenta" (value 2)
      page.execute_script("$('#pedido_tipo_pedido').val(2).trigger('change')")
      sleep 0.5

      # Change cuenta to cuenta2
      page.execute_script(<<~JS)
        var $el = $('#pedido_cuenta_id');
        if ($el.find('option[value="#{cuenta2.id}"]').length === 0) {
          $el.append(new Option('#{cuenta2.cliente_y_nombre}', #{cuenta2.id}));
        }
        $el.val(#{cuenta2.id}).trigger('change');
      JS

      wait_for_ajax
      expect(page).to have_css('#productos-en-venta', wait: 10)

      # Verify DB updated immediately after cambiar_cuenta AJAX
      pedido.reload
      expect(pedido.cuenta_id).to eq(cuenta2.id), 'cuenta_id should be updated to cuenta2 after cambiar_cuenta AJAX'

      # Add a product
      producto_card = page.find('.producto-venta', text: producto.nombre, wait: 10)
      within(producto_card) { find('a.mas').click }
      wait_for_ajax

      # Go to cart (use #boton-compra to target the main button, not the cart dropdown)
      within('#boton-compra') do
        find('a.boton-aceptar-pedido', wait: 10).click
      end
      expect(page).to have_current_path(%r{/pedidos/#{pedido.id}/comprar}, wait: 10)

      # Finalizar compra
      page.find('#confirmar_pedido', text: /Finalizar Compra/i, wait: 10).click

      # Should redirect to show page with success
      expect(page).to have_content(/exitoso/i, wait: 15)

      # Verify the pedido has the new cuenta after finalizar
      pedido.reload
      expect(pedido.cuenta_id).to eq(cuenta2.id)
      expect(pedido.pedido_para_empresa).to be true
    end
  end

  describe 'changing usuario persists through finalizar' do
    it 'updates pedido usuario and cuenta when admin changes usuario and finalizes' do
      # Create pedido for usuario1
      pedido = Pedidos::Pedido.new(
        tienda: tienda, cuenta: cuenta1, usuario: usuario1, fecha: Date.current,
        estado_id: 1, autor: admin,
        pedido_para_empresa: false
      )
      pedido.save(validate: false)

      admin_login(admin, 'password123')
      visit edit_pedido_path(pedido)

      expect(page).to have_css('#productos-en-venta', wait: 15)

      # Ensure tipo_pedido is "Usuario" (value 1)
      page.execute_script("$('#pedido_tipo_pedido').val(1).trigger('change')")
      sleep 0.5

      # Change usuario to usuario2 via select2 remote
      page.execute_script(<<~JS)
        var $el = $('#pedido_usuario_id');
        $el.select2('data', {id: #{usuario2.id}, nombre_y_cliente: '#{usuario2.nombre}'}, true);
      JS

      wait_for_ajax
      expect(page).to have_css('#productos-en-venta', wait: 10)

      # Verify DB updated immediately after cambiar_cuenta AJAX:
      # usuario_id should be updated and cuenta_id should reflect the new usuario's cuenta
      pedido.reload
      expect(pedido.usuario_id).to eq(usuario2.id), 'usuario_id should be updated after cambiar_cuenta AJAX'
      expect(pedido.cuenta_id).to eq(cuenta2.id), "cuenta_id should be updated to match new usuario's cuenta after cambiar_cuenta AJAX"

      # Add a product
      producto_card = page.find('.producto-venta', text: producto.nombre, wait: 10)
      within(producto_card) { find('a.mas').click }
      wait_for_ajax

      # Go to cart (use #boton-compra to target the main button, not the cart dropdown)
      within('#boton-compra') do
        find('a.boton-aceptar-pedido', wait: 10).click
      end
      expect(page).to have_current_path(%r{/pedidos/#{pedido.id}/comprar}, wait: 10)

      # Finalizar compra
      page.find('#confirmar_pedido', text: /Finalizar Compra/i, wait: 10).click

      # Should redirect to show page with success
      expect(page).to have_content(/exitoso/i, wait: 15)

      # Verify the pedido has the new usuario and correct cuenta
      pedido.reload
      expect(pedido.usuario_id).to eq(usuario2.id)
      expect(pedido.cuenta_id).to eq(cuenta2.id)
    end
  end
end
