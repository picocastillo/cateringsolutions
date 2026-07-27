# frozen_string_literal: true

require 'rails_helper'

# TDD spec: admin opens pedido/edit — usuario/cuenta select2 must be pre-filled.
# Use-cases:
#   1. Pedido has usuario → tipo_pedido=1 (Usuario), usuario select shows user name
#   2. Pedido has ONLY cuenta (no usuario) → tipo_pedido=2 (Cuenta), cuenta select shows cuenta name
#   3. Pedido is part of a group → navigating via edit still shows the correct usuario
RSpec.describe 'Admin edita pedido — usuario/cuenta cargado en select2', :js, type: :system do
  let!(:tienda) do
    create(:tienda, nombre: 'Admin Edit Store', dominio: 'localhost',
                    carrito_de_compras: true, maneja_stock: false,
                    horarios_de_entrega: false)
  end

  let!(:admin) do
    create(:usuario, :admin, :with_password,
           login: 'admin_edit_test',
           nombre: 'Admin Editor',
           email: 'admineditor@test.com',
           visualizando_tienda: tienda).tap do |u|
      u.tiendas << tienda unless u.tiendas.include?(tienda)
    end
  end

  let!(:cliente) do
    create(:cliente, tienda: tienda, nombre: 'Cliente Select2',
                     cuenta_corriente: true,
                     horarios_de_entrega: false,
                     usuario_puede_elegir_cuenta: false,
                     permitir_envios_a_domicilio: false)
  end

  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta Select2', cliente: cliente, cuenta_corriente_parcial: true) }

  let!(:usuario_cliente) do
    create(:usuario, :cliente,
           login: 'cliente_select2',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Juan Pérez',
           email: 'juan@select2.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let!(:categoria) do
    create(:categoria, nombre: 'Cat Select2', tienda: tienda, stock_activo: false, menu_diario: false)
  end

  let!(:producto) do
    create(:producto, nombre: 'Producto Select2', tienda: tienda, categoria: categoria)
  end

  before do
    create(:categoria, nombre: 'Menu Dummy', tienda: tienda, menu_diario: true)
    cliente.categorias << categoria unless cliente.categorias.include?(categoria)
    create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 150)
  end

  def make_pedido(usuario: usuario_cliente, cuenta: self.cuenta)
    p = build(:pedido,
              tienda: tienda,
              cuenta: cuenta,
              usuario: usuario,
              estado_id: 1,
              fecha: Date.current + 1,
              autor: admin,
              pedido_para_empresa: usuario.nil?)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    p
  end

  context 'pedido con usuario asignado' do
    it 'muestra el nombre del usuario en el select2 al cargar la página' do
      pedido = make_pedido
      admin_login(admin)
      visit edit_pedido_path(pedido)

      # Wait for select2 to initialize
      expect(page).to have_css('#carga-pedidos', wait: 15)

      # The usuario select2 should show the user's name, NOT the placeholder
      select2_text = page.evaluate_script("$('#s2id_pedido_usuario_id .select2-chosen').text()")
      expect(select2_text).to include('Juan')
      expect(select2_text).not_to eq('Ingrese nombre, legajo o DNI')

      # The usuario wrapper should be visible (tipo_pedido == 1)
      expect(page).to have_css('.pedido_usuario_id:not(.hide)', wait: 5)
    end

    it 'mantiene el usuario después de un refresh (F5)' do
      pedido = make_pedido
      admin_login(admin)
      visit edit_pedido_path(pedido)
      expect(page).to have_css('#carga-pedidos', wait: 15)

      # Reload
      visit edit_pedido_path(pedido)
      expect(page).to have_css('#carga-pedidos', wait: 15)

      select2_text = page.evaluate_script("$('#s2id_pedido_usuario_id .select2-chosen').text()")
      expect(select2_text).to include('Juan')
    end
  end

  context 'pedido con SOLO cuenta (sin usuario)' do
    it 'muestra "Cuenta" en el selector Para al cargar la página' do
      pedido = make_pedido(usuario: nil, cuenta: cuenta)
      admin_login(admin)
      visit edit_pedido_path(pedido)

      expect(page).to have_css('#carga-pedidos', wait: 15)

      # The "Para" select must show "Cuenta" (value=2), not "Usuario" (value=1)
      # Wait up to 5s for any AJAX / onmount to settle
      expect(page).to have_select('pedido_tipo_pedido', selected: 'Cuenta', wait: 5)
    end

    # TDD: applyTipoPedidoUI() is called by App.onMount('#new-pedido').
    # It reads the pedido's actual state (usuario pre.id, cuenta selected value)
    # and enforces the correct Para value + field visibility, even if a stale
    # Turbolinks cache or plugin previously set the select to "Usuario".
    it 'applyTipoPedidoUI restaura Para a Cuenta cuando el pedido tiene cuenta y no usuario' do
      pedido = make_pedido(usuario: nil, cuenta: cuenta)
      admin_login(admin)
      visit edit_pedido_path(pedido)

      expect(page).to have_css('#carga-pedidos', wait: 15)

      # Simulate the bug: something (stale Turbolinks cache / plugin) resets Para to Usuario
      page.execute_script(<<~JS)
        $('#pedido_tipo_pedido').val('1');
        $('.pedido_usuario_id').removeClass('hide');
        $('.pedido_cuenta_id').addClass('hide');
      JS

      expect(page).to have_select('pedido_tipo_pedido', selected: 'Usuario')

      # Re-run the mount initializer (what happens on every Turbolinks navigation)
      page.execute_script('applyTipoPedidoUI();')

      # Must restore Para=Cuenta and correct field visibility
      expect(page).to have_select('pedido_tipo_pedido', selected: 'Cuenta', wait: 5)
      expect(page).to have_css('.pedido_usuario_id.hide', visible: :all, wait: 5)
      expect(page).to have_css('.pedido_cuenta_id:not(.hide)', wait: 5)
    end

    # Regression: cambiar_cuenta was clearing cuenta+pedido_para_empresa whenever
    # the form was POSTed with usuario_id="" (which happens in Cuenta mode when JS fires
    # the action from a fecha/cuenta change event). Next page-load showed "Para = Usuario".
    it 'cambiar_cuenta con usuario_id vacío y tipo_pedido=2 no corrompe la base de datos' do
      pedido = make_pedido(usuario: nil, cuenta: cuenta)
      admin_login(admin)
      visit edit_pedido_path(pedido)
      expect(page).to have_css('#carga-pedidos', wait: 15)

      # Simulate what JS does when it fires cambiar_cuenta in Cuenta mode with a blank usuario_id
      page.execute_script(<<~JS)
        var csrfToken = encodeURIComponent($('meta[name="csrf-token"]').attr("content") || '');
        $.ajax({
          url: '/pedidos/#{pedido.id}/cambiar_cuenta',
          type: 'POST',
          async: false,
          dataType: 'script',
          data: $.param({
            authenticity_token: decodeURIComponent(csrfToken),
            utf8: '✓',
            pedido: { tipo_pedido: '2', usuario_id: '', cuenta_id: '#{cuenta.id}', fecha: '#{Date.current + 1}' }
          })
        });
      JS

      # DB must not have been corrupted — pedido_para_empresa stays true, cuenta_id stays set
      pedido.reload
      expect(pedido.pedido_para_empresa).to be(true),
                                            'cambiar_cuenta borró pedido_para_empresa (ahora false)'
      expect(pedido.cuenta_id).to eq(cuenta.id),
                                  'cambiar_cuenta borró cuenta_id (ahora nil)'

      # And on the next page load "Para" must still show "Cuenta"
      visit edit_pedido_path(pedido)
      expect(page).to have_css('#carga-pedidos', wait: 15)
      expect(page).to have_select('pedido_tipo_pedido', selected: 'Cuenta', wait: 5)
    end

    it 'muestra la cuenta en el select2 y oculta el campo usuario' do
      pedido = make_pedido(usuario: nil, cuenta: cuenta)
      admin_login(admin)
      visit edit_pedido_path(pedido)

      expect(page).to have_css('#carga-pedidos', wait: 15)

      # tipo_pedido should be 2 (Cuenta), so cuenta select visible and usuario hidden
      expect(page).to have_css('.pedido_cuenta_id:not(.hide)', wait: 5)
      expect(page).to have_css('.pedido_usuario_id.hide', visible: :all, wait: 5)

      # The cuenta select2 should have the cuenta name selected
      selected_val = page.evaluate_script("$('#pedido_cuenta_id').val()")
      expect(selected_val.to_s).to eq(cuenta.id.to_s)
    end
  end

  context 'pedido en grupo (navegación entre pedidos)' do
    it 'carga el usuario correcto al navegar entre pedidos del grupo' do
      grupo = Pedidos::PedidoMultiple.create!(usuario: admin)
      pedido1 = make_pedido
      pedido1.update_column(:pedido_multiple_id, grupo.id)
      pedido2 = make_pedido
      pedido2.update_column(:pedido_multiple_id, grupo.id)

      admin_login(admin)

      # Visit first pedido
      visit edit_pedido_path(pedido1)
      expect(page).to have_css('#carga-pedidos', wait: 15)

      text1 = page.evaluate_script("$('#s2id_pedido_usuario_id .select2-chosen').text()")
      expect(text1).to include('Juan')

      # Navigate to second pedido
      visit edit_pedido_path(pedido2)
      expect(page).to have_css('#carga-pedidos', wait: 15)

      text2 = page.evaluate_script("$('#s2id_pedido_usuario_id .select2-chosen').text()")
      expect(text2).to include('Juan')
    end
  end

  # TDD: changing fecha when admin has a usuario selected must create a sibling pedido,
  # NOT vaciar carrito. The bug was that serializeClosestForm() included cuenta_id=""
  # (the hidden cuenta field), which caused cambiar_cuenta to set @pedido.cuenta = nil,
  # making cuenta_id_changed? = true and bypassing the sibling creation path.
  context 'admin crea multi-pedido cambiando fecha con usuario seleccionado' do
    let(:fecha1) do
      d = Date.current + 1.day
      d += 1.day while d.saturday? || d.sunday?
      d
    end

    let(:fecha2) do
      d = fecha1 + 1.day
      d += 1.day while d.saturday? || d.sunday?
      d
    end

    let!(:pedido_con_producto) do
      p = build(:pedido,
                tienda: tienda,
                cuenta: cuenta,
                usuario: usuario_cliente,
                estado_id: 1,
                fecha: fecha1,
                autor: admin)
      p.asignar_cuenta_manual
      p.cuenta = cuenta
      p.save!
      create(:producto_solicitado, pedido: p, producto: producto, cantidad: 1, precio_unitario: 150.0)
      p
    end

    it 'crea un pedido hermano en lugar de vaciar el carrito al cambiar la fecha' do
      admin_login(admin)
      visit edit_pedido_path(pedido_con_producto)
      expect(page).to have_css('#carga-pedidos', wait: 15)

      # Confirm we are on pedido1 with product loaded
      expect(page).to have_css('.listado-eliminable', wait: 5)

      # Simulate fecha change exactly as the JS does — with usuario_id present and cuenta_id blank
      # (because in tipo_pedido=1 mode the cuenta field is hidden but still serialized as empty)
      page.execute_script(<<~JS)
        var csrfToken = encodeURIComponent($('meta[name="csrf-token"]').attr("content") || '');
        $.ajax({
          url: '/pedidos/#{pedido_con_producto.id}/cambiar_cuenta',
          type: 'POST',
          dataType: 'script',
          data: $.param({
            authenticity_token: decodeURIComponent(csrfToken),
            utf8: '✓',
            pedido: {
              tipo_pedido: '1',
              usuario_id: '#{usuario_cliente.id}',
              cuenta_id: '',
              fecha: '#{fecha2.strftime('%d/%m/%Y')}'
            }
          })
        });
      JS

      # Wait for the AJAX + possible redirect JS to run
      sleep 0.5
      page.evaluate_async_script(<<~JS)
        var done = arguments[0];
        if (jQuery.active === 0) { done(); }
        else { jQuery(document).one('ajaxStop', done); }
      JS

      # Should have navigated to a new sibling pedido (different path)
      expect(page).to have_current_path(
        %r{/pedidos/(?!#{pedido_con_producto.id}/edit)\d+/edit}, wait: 10
      )

      # The original pedido must STILL have its product (not vaciar'd)
      expect(pedido_con_producto.reload.productos_solicitados.count).to eq(1)

      # A sibling pedido must exist in the group with the new fecha
      pedido_con_producto.reload
      expect(pedido_con_producto.en_grupo?).to be(true)
      grupo = pedido_con_producto.pedido_multiple
      hermano = grupo.pedidos.find_by(fecha: fecha2)
      expect(hermano).to be_present
      expect(hermano.id).not_to eq(pedido_con_producto.id)
    end

    it 'los productos del pedido original no se eliminan al crear el hermano' do
      admin_login(admin)
      visit edit_pedido_path(pedido_con_producto)
      expect(page).to have_css('#carga-pedidos', wait: 15)
      expect(page).to have_css('.listado-eliminable', wait: 5)

      initial_count = pedido_con_producto.productos_solicitados.count

      # Trigger fecha change via direct AJAX (mimics what serializeClosestForm sends in tipo=1 mode)
      page.execute_script(<<~JS)
        var csrfToken = encodeURIComponent($('meta[name="csrf-token"]').attr("content") || '');
        $.ajax({
          url: '/pedidos/#{pedido_con_producto.id}/cambiar_cuenta',
          type: 'POST',
          async: false,
          dataType: 'script',
          data: $.param({
            authenticity_token: decodeURIComponent(csrfToken),
            utf8: '✓',
            pedido: {
              tipo_pedido: '1',
              usuario_id: '#{usuario_cliente.id}',
              cuenta_id: '',
              fecha: '#{fecha2.strftime('%d/%m/%Y')}'
            }
          })
        });
      JS

      expect(pedido_con_producto.reload.productos_solicitados.count).to eq(initial_count),
                                                                        'cambiar_cuenta eliminó los productos del pedido original al cambiar la fecha (vaciar carrito incorrecto)'
    end
  end
end
