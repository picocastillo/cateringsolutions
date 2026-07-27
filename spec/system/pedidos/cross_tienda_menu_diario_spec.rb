# frozen_string_literal: true

require 'rails_helper'

# Bug: when a cliente with access to two tiendas creates a pedido in tienda A
# (which has soporta_productos_diarios), changes fecha to create a sibling,
# switches to tienda B, and then clicks the gbs-tab pointing back at the first
# (tienda A) pedido — the page navigates back but the menu-del-día panel
# (#opciones-del-dia) does NOT load. A manual page refresh is required to see
# it.
#
# Root cause hypothesis: cross-tienda navigation via gbs-tab uses
# data-turbolinks="false" → full browser reload. On the reloaded page some
# combination of (deferred bundle / Turbolinks initialisation / App.onMount
# registration / lazy AJAX firing) misses the #opciones-del-dia[data-pedido-id]
# placeholder and the AJAX is never fired.
RSpec.describe 'Cross-tienda menu-del-día render', :js, type: :system do
  let!(:tienda_a) do
    create(:tienda, nombre: 'TA', dominio: 'localhost',
                    carrito_de_compras: true, horarios_de_entrega: false,
                    maneja_stock: false, soporta_productos_diarios: true,
                    muestra_menus_del_dia: true, multiple_locales: false)
  end
  let!(:tienda_b) do
    # multiple_locales: true on the SOURCE tienda is what triggers the bug.
    # The autor's tienda_activa (still tienda_b before reload) is checked by
    # `verificar_local`, which adds an error → @pedido.valid? returns false →
    # _productos_en_venta partial renders empty.
    create(:tienda, nombre: 'TB', dominio: 'localhost',
                    carrito_de_compras: true, horarios_de_entrega: false,
                    maneja_stock: false, soporta_productos_diarios: true,
                    muestra_menus_del_dia: true, multiple_locales: true)
  end

  let!(:cliente) do
    create(:cliente, tiendas: [tienda_a, tienda_b],
                     nombre: 'Cliente Cross', cuenta_corriente: false,
                     horarios_de_entrega: false,
                     permitir_envios_a_domicilio: false,
                     usuario_puede_elegir_cuenta: false)
  end
  let!(:cuenta) { create(:cuenta, nombre: 'Cuenta Cross', cliente: cliente) }

  let!(:usuario) do
    create(:usuario, :cliente,
           login: 'crossuser',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Cross User',
           email: 'cross@test.com',
           cuenta: cuenta,
           tienda_cliente: tienda_a,
           visualizando_tienda: tienda_a)
  end

  let!(:cat_a) { create(:categoria, nombre: 'Cat A', tienda: tienda_a, stock_activo: false) }
  let!(:cat_b) { create(:categoria, nombre: 'Cat B', tienda: tienda_b, stock_activo: false) }
  let!(:prod_a) { create(:producto, nombre: 'Prod A', tienda: tienda_a, categoria: cat_a) }
  let!(:prod_diario_a) { create(:producto, nombre: 'Diario A', tienda: tienda_a, categoria: cat_a) }
  let!(:prod_b) { create(:producto, nombre: 'Prod B', tienda: tienda_b, categoria: cat_b) }

  let(:fecha_a) { cuenta.proximo_dia_pedido }
  let(:fecha_b) do
    f = fecha_a + 1.day
    f += 1.day while f.saturday? || f.sunday?
    f
  end

  let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: usuario, cuenta: cuenta) }

  let!(:pedido_a) do
    p = build(:pedido, tienda: tienda_a, cuenta: cuenta, estado_id: 1,
                       fecha: fecha_a, autor: usuario, usuario: usuario,
                       pedido_multiple_id: grupo.id)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    Productos::ProductoSolicitado.new(pedido: p, producto: prod_a,
                                      cantidad: 1, precio_unitario: 100.0)
                                 .save(validate: false)
    p
  end

  let!(:pedido_b) do
    p = build(:pedido, tienda: tienda_b, cuenta: cuenta, estado_id: 1,
                       fecha: fecha_b, autor: usuario, usuario: usuario,
                       pedido_multiple_id: grupo.id)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    p
  end

  let!(:menu_pd_a) do
    MenusDiarios::MenuDiario.create!(productos: [prod_diario_a],
                                     fecha: fecha_a, descripcion: 'Selección Tienda A',
                                     tienda: tienda_a, autor: usuario,
                                     tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
  end

  before do
    create(:precio, :for_cliente, producto: prod_a,         cliente: cliente,
                                  importe: 100, fecha_desde: Time.zone.today)
    create(:precio, :for_cliente, producto: prod_diario_a,  cliente: cliente,
                                  importe: 250, fecha_desde: Time.zone.today)
    create(:precio, :for_cliente, producto: prod_b,         cliente: cliente,
                                  importe: 150, fecha_desde: Time.zone.today)

    cliente_login(usuario)
  end

  it 'renders #opciones-del-dia panel after navigating from tienda B back to tienda A pedido' do
    # Step 1: simulate user is now in tienda B (their session is on tienda_b)
    usuario.update!(visualizando_tienda: tienda_b, tienda_cliente: tienda_b)

    # Step 2: visit pedido_b in tienda B
    visit edit_pedido_path(pedido_b)
    expect(page).to have_css('#carga-pedidos', wait: 10)

    # Wait for the menu-del-día placeholder OR confirm there's none for B
    # (pedido_b has no menu_pd, but the placeholder should be present because
    # tienda_b also has soporta_productos_diarios — the lazy AJAX returns empty)
    expect(page).to have_css('a.gbs-tab', minimum: 2, wait: 10)

    # Step 3: click the gbs-tab that points to pedido_a (in tienda A).
    # This is the cross-tienda navigation that triggers the bug.
    tab_a = find("a.gbs-tab[href='#{edit_pedido_path(pedido_a)}']")
    tab_a.click

    # Step 4: must land on pedido_a's edit page in tienda A
    expect(page).to have_current_path(edit_pedido_path(pedido_a), wait: 15)
    expect(page).to have_css('#carga-pedidos', wait: 10)

    # Step 5: THE BUG: after this navigation the #opciones-del-dia-section
    # must render (loaded async via the productos_diarios_panel AJAX). Without
    # the fix, the placeholder stays visible (#opciones-del-dia-loader) or
    # nothing renders at all, requiring a manual refresh.
    expect(page).to have_css('#opciones-del-dia-section', wait: 15),
                    'opciones-del-dia-section did not render after cross-tienda navigation. ' \
                    'This is the bug — manual refresh would be required.'
    expect(page).to have_no_css('#opciones-del-dia-loader', wait: 10)

    # And the menu-del-día product is actually visible
    within('#opciones-del-dia-section') do
      expect(page).to have_content('Selección Tienda A')
      expect(page).to have_content('Diario A')
    end
  end
end
