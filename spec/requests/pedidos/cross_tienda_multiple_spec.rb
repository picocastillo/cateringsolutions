require 'rails_helper'

# Cross-tienda PedidoMultiple support: a single shared cliente shopping in
# tienda A and tienda B can keep ONE PedidoMultiple group spanning both
# tiendas. Behavior covered:
#   * Switching tiendas with an EMPTY pendiente pedido retags it to the new
#     tienda (the empty shell follows the user).
#   * Switching tiendas with a pendiente pedido that has productos leaves it
#     in the old tienda; landing on /pedidos/new in the new tienda creates a
#     fresh shell auto-enrolled into the same group.
#   * PedidoMultiple#abiertos surfaces groups with pendiente children.
RSpec.describe 'Cross-tienda PedidoMultiple', type: :request do
  let!(:tienda_a) { create(:tienda, dominio: 'a.example.com', carrito_de_compras: true, maneja_stock: false, horarios_de_entrega: false) }
  let!(:tienda_b) { create(:tienda, dominio: 'b.example.com', carrito_de_compras: true, maneja_stock: false, horarios_de_entrega: false) }

  let!(:cliente) do
    create(:cliente, tiendas: [tienda_a, tienda_b], cuenta_corriente: true,
                     horarios_de_entrega: false, usuario_puede_elegir_cuenta: false,
                     permitir_envios_a_domicilio: false)
  end
  let!(:cuenta) { create(:cuenta, cliente: cliente, cuenta_corriente_parcial: true) }

  let!(:cliente_user) do
    u = build(:usuario, cuenta: cuenta, tienda_cliente: tienda_a, tipo_usuario_id: 1,
                        login: "client-#{SecureRandom.hex(3)}")
    u.password = u.password_confirmation = 'secret123'
    u.crypted_password = nil
    u.salt = nil
    u.save!
    u
  end

  let!(:categoria_a) { create(:categoria, nombre: 'Cat A', tienda: tienda_a, stock_activo: false) }
  let!(:producto_a)  { create(:producto, tienda: tienda_a, categoria: categoria_a) }

  before do
    create(:precio, :for_cliente, producto: producto_a, cliente: cliente,
                                  importe: 100, fecha_desde: Date.current - 1.day)
    host! tienda_a.dominio
    post '/public', params: { username: cliente_user.login, password: 'secret123' }
  end

  describe 'PedidoMultiple#abiertos scope' do
    it 'returns only groups that have at least one pendiente child' do
      grupo_abierto = Pedidos::PedidoMultiple.create!(usuario: cliente_user, cuenta: cuenta)
      grupo_cerrado = Pedidos::PedidoMultiple.create!(usuario: cliente_user, cuenta: cuenta)

      build_pedido(tienda: tienda_a, estado_id: 1, grp: grupo_abierto)
      cerrado = build_pedido(tienda: tienda_a, estado_id: 1, grp: grupo_cerrado)
      Pedidos::Pedido.where(id: cerrado.id).update_all(estado_id: 2)

      expect(Pedidos::PedidoMultiple.abiertos).to contain_exactly(grupo_abierto)
    end
  end

  describe 'switching tiendas with an empty pendiente pedido' do
    let!(:pedido_vacio) do
      build_pedido(tienda: tienda_a, estado_id: 1, fecha: next_weekday)
    end

    it 'retags the empty pedido to the new tienda' do
      expect do
        post '/tiendas/cambiar_tienda_activa', params: { tienda_activa_id: tienda_b.id }
      end.to change { pedido_vacio.reload.tienda_id }.from(tienda_a.id).to(tienda_b.id)
    end
  end

  describe 'switching tiendas with a pendiente pedido that has productos AND is in a multi group' do
    let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: cliente_user, cuenta: cuenta) }
    let!(:pedido_con_productos) do
      p = build_pedido(tienda: tienda_a, estado_id: 1, fecha: next_weekday, grp: grupo)
      ps = Productos::ProductoSolicitado.new(pedido: p, producto: producto_a,
                                             cantidad: 1, precio_unitario: 100.0)
      ps.save(validate: false)
      p
    end

    it 'leaves the old pedido in tienda A and keeps its productos' do
      expect do
        post '/tiendas/cambiar_tienda_activa', params: { tienda_activa_id: tienda_b.id }
      end.not_to(change { pedido_con_productos.reload.tienda_id })
      expect(pedido_con_productos.productos_solicitados.count).to eq(1)
    end
  end

  describe 'switching tiendas with a pendiente simple pedido (NOT in a group) that has productos' do
    let!(:pedido_simple_con_productos) do
      p = build_pedido(tienda: tienda_a, estado_id: 1, fecha: next_weekday)
      ps = Productos::ProductoSolicitado.new(pedido: p, producto: producto_a,
                                             cantidad: 1, precio_unitario: 100.0)
      ps.save(validate: false)
      p
    end

    it 'discards productos, retags the empty shell to tienda B, and redirects with carrito_descartado param' do
      post '/tiendas/cambiar_tienda_activa', params: { tienda_activa_id: tienda_b.id }
      pedido_simple_con_productos.reload
      expect(pedido_simple_con_productos.tienda_id).to eq(tienda_b.id)
      expect(pedido_simple_con_productos.productos_solicitados.count).to eq(0)
      expect(response.location).to include("carrito_descartado=#{CGI.escape(tienda_a.nombre)}")
    end
  end

  describe 'GET /pedidos/new auto-enrolls the new shell into an open group' do
    let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: cliente_user, cuenta: cuenta) }
    let!(:pedido_grupo_a) do
      p = build_pedido(tienda: tienda_a, estado_id: 1, fecha: next_weekday, grp: grupo)
      ps = Productos::ProductoSolicitado.new(pedido: p, producto: producto_a,
                                             cantidad: 2, precio_unitario: 100.0)
      ps.save(validate: false)
      p
    end

    before do
      # Switch to tienda B (no empty shell to retag, only the products-having
      # pedido in A which stays put). Re-login on tienda B's host so the
      # session cookie is valid for that domain.
      cliente_user.update_columns(tienda_cliente_id: tienda_b.id, visualizando_tienda_id: tienda_b.id)
      host! tienda_b.dominio
      post '/public', params: { username: cliente_user.login, password: 'secret123' }
    end

    it 'creates a new pedido in tienda B and attaches it to the same group' do
      expect do
        get '/pedidos/new'
      end.to change { Pedidos::Pedido.where(tienda_id: tienda_b.id).count }.by(1)

      nuevo = Pedidos::Pedido.where(tienda_id: tienda_b.id).order(:id).last
      expect(nuevo.pedido_multiple_id).to eq(grupo.id)
      expect(grupo.pedidos.reload.pluck(:tienda_id)).to contain_exactly(tienda_a.id, tienda_b.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Bug 1: when the user already has a sibling for `proximo_dia_pedido` in
  # tienda A, the auto-enrolled new shell in tienda B must NOT also pick that
  # same fecha — it should advance to the next valid weekday so the group has
  # distinct dates and the badge strip doesn't show duplicates.
  # ---------------------------------------------------------------------------
  describe 'Bug 1: auto-enrolled shell in new tienda gets a non-conflicting fecha' do
    let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: cliente_user, cuenta: cuenta) }
    let(:fecha_a) { cuenta.proximo_dia_pedido }
    let!(:pedido_grupo_a) do
      p = build_pedido(tienda: tienda_a, estado_id: 1, fecha: fecha_a, grp: grupo)
      ps = Productos::ProductoSolicitado.new(pedido: p, producto: producto_a,
                                             cantidad: 2, precio_unitario: 100.0)
      ps.save(validate: false)
      p
    end

    before do
      cliente_user.update_columns(tienda_cliente_id: tienda_b.id, visualizando_tienda_id: tienda_b.id)
      host! tienda_b.dominio
      post '/public', params: { username: cliente_user.login, password: 'secret123' }
    end

    it 'advances the new shell fecha to the next weekday that is not already taken in the group' do
      get '/pedidos/new'

      nuevo = Pedidos::Pedido.where(tienda_id: tienda_b.id).order(:id).last
      expect(nuevo.fecha).not_to eq(fecha_a),
                                 "expected new shell to skip #{fecha_a} (already taken in tienda A) " \
                                 "but got #{nuevo.fecha}"
      expect(nuevo.fecha).to be > fecha_a
      expect(nuevo.fecha.saturday?).to be(false)
      expect(nuevo.fecha.sunday?).to be(false)
    end
  end

  # ---------------------------------------------------------------------------
  # Bug 3: clicking a sibling pedido that lives in another tienda must
  # transparently switch tienda_activa (so authorization passes) and render
  # that pedido's edit page in the correct tienda context.
  # ---------------------------------------------------------------------------
  describe 'Bug 3: editing a sibling pedido in a different tienda auto-switches tienda_activa' do
    let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: cliente_user, cuenta: cuenta) }
    let!(:pedido_en_a) do
      p = build_pedido(tienda: tienda_a, estado_id: 1,
                       fecha: cuenta.proximo_dia_pedido, grp: grupo)
      ps = Productos::ProductoSolicitado.new(pedido: p, producto: producto_a,
                                             cantidad: 1, precio_unitario: 100.0)
      ps.save(validate: false)
      p
    end

    before do
      # User is currently logged in tienda B
      cliente_user.update_columns(tienda_cliente_id: tienda_b.id, visualizando_tienda_id: tienda_b.id)
      host! tienda_b.dominio
      post '/public', params: { username: cliente_user.login, password: 'secret123' }
    end

    it 'updates visualizando_tienda_id when editing a pedido that belongs to a sibling tienda' do
      expect do
        get edit_pedido_path(pedido_en_a)
      end.to change { cliente_user.reload.visualizando_tienda_id }.from(tienda_b.id).to(tienda_a.id)
    end

    it 'renders the edit page successfully (no 403 / no AccessDenied)' do
      get edit_pedido_path(pedido_en_a)
      expect(response).to have_http_status(:ok).or have_http_status(:found)
      # If it redirected (e.g. cross-domain), follow once and ensure no auth error
      follow_redirect! if response.redirect?
      expect(response.body).not_to include('AccessDenied')
    end
  end

  # ---------------------------------------------------------------------------
  # Bug 2: after switching tienda and adding products to the new shell,
  # changing fecha must create a sibling in the same tienda — the existing
  # cambiar_cuenta sibling-creation branch must still trigger.
  # ---------------------------------------------------------------------------
  describe 'Bug 2: fecha change on the cross-tienda shell creates a sibling' do
    let!(:categoria_b) { create(:categoria, nombre: 'Cat B', tienda: tienda_b, stock_activo: false) }
    let!(:producto_b)  { create(:producto, tienda: tienda_b, categoria: categoria_b) }
    let!(:precio_b) do
      create(:precio, :for_cliente, producto: producto_b, cliente: cliente,
                                    importe: 200, fecha_desde: Date.current - 1.day)
    end
    let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: cliente_user, cuenta: cuenta) }
    let(:fecha_a) { cuenta.proximo_dia_pedido }
    let(:fecha_b) do
      f = fecha_a + 1.day
      f += 1.day while f.saturday? || f.sunday?
      f
    end
    let(:fecha_c) do
      f = fecha_b + 1.day
      f += 1.day while f.saturday? || f.sunday?
      f
    end
    let!(:pedido_a) do
      p = build_pedido(tienda: tienda_a, estado_id: 1, fecha: fecha_a, grp: grupo)
      ps = Productos::ProductoSolicitado.new(pedido: p, producto: producto_a,
                                             cantidad: 1, precio_unitario: 100.0)
      ps.save(validate: false)
      p
    end
    let!(:pedido_b) do
      p = build_pedido(tienda: tienda_b, estado_id: 1, fecha: fecha_b, grp: grupo)
      ps = Productos::ProductoSolicitado.new(pedido: p, producto: producto_b,
                                             cantidad: 1, precio_unitario: 200.0)
      ps.save(validate: false)
      p
    end

    before do
      cliente_user.update_columns(tienda_cliente_id: tienda_b.id, visualizando_tienda_id: tienda_b.id)
      host! tienda_b.dominio
      post '/public', params: { username: cliente_user.login, password: 'secret123' }
    end

    it 'creates a new sibling pedido in tienda B when fecha changes on pedido_b' do
      expect do
        post "/pedidos/#{pedido_b.id}/cambiar_cuenta",
             params: {
               pedido: {
                 fecha: fecha_c.strftime('%d/%m/%Y'),
                 cuenta_id: cuenta.id,
                 usuario_id: cliente_user.id
               }
             },
             headers: { 'Accept' => 'text/javascript' }
      end.to change { grupo.pedidos.reload.where(tienda_id: tienda_b.id).count }.by(1)

      nuevo = grupo.pedidos.where(tienda_id: tienda_b.id, fecha: fecha_c).first
      expect(nuevo).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # Bug 4: Cliente in tienda B clicks first sibling pedido (in tienda A) via
  # gbs-tab. The cross-tienda load_pedido switch happens, edit page renders.
  # The product listado / panels MUST be present on this same first request —
  # not require a manual reload to see them.
  # ---------------------------------------------------------------------------
  describe 'Bug 4: editing tienda-A sibling from tienda B renders products listado on first request' do
    let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: cliente_user, cuenta: cuenta) }
    let(:fecha_a) { cuenta.proximo_dia_pedido }
    let(:fecha_b) do
      f = fecha_a + 1.day
      f += 1.day while f.saturday? || f.sunday?
      f
    end
    let!(:pedido_a) do
      # Pedido in tienda A WITH products
      p = build_pedido(tienda: tienda_a, estado_id: 1, fecha: fecha_a, grp: grupo)
      ps = Productos::ProductoSolicitado.new(pedido: p, producto: producto_a,
                                             cantidad: 2, precio_unitario: 100.0)
      ps.save(validate: false)
      p
    end
    let!(:pedido_b) do
      # Empty sibling shell in tienda B
      build_pedido(tienda: tienda_b, estado_id: 1, fecha: fecha_b, grp: grupo)
    end

    before do
      # Enable visibility flags so the lazy panels render in the response
      tienda_a.update!(soporta_productos_diarios: true, muestra_menus_del_dia: true,
                       muestra_mas_productos: true)
      tienda_b.update!(soporta_productos_diarios: true, muestra_menus_del_dia: true,
                       muestra_mas_productos: true)
      # User is currently sitting in tienda B
      cliente_user.update_columns(tienda_cliente_id: tienda_b.id, visualizando_tienda_id: tienda_b.id)
      host! tienda_b.dominio
      post '/public', params: { username: cliente_user.login, password: 'secret123' }
    end

    it 'renders the menu-del-día and mas-productos panels on the SAME request that switches tiendas' do
      get edit_pedido_path(pedido_a)

      # Must succeed (cross-tienda auto-switch should let authorization pass)
      expect(response).to have_http_status(:ok),
                          "expected 200 but got #{response.status}: #{response.body[0..200]}"

      # The user's tienda_activa must now be tienda A
      expect(cliente_user.reload.visualizando_tienda_id).to eq(tienda_a.id)

      # Panels must render on this very response — NOT require a second
      # manual reload. These are server-rendered placeholders/sections, not
      # async content, so they should appear in the body immediately.
      expect(response.body).to include('opciones-del-dia'),
                               'Lazy menu-del-día placeholder MISSING — _productos_en_venta partial did not render the soporta_productos_diarios branch on first request after cross-tienda switch.'
      expect(response.body).to include('top-menus-diarios'),
                               'Top menus diarios placeholder MISSING — muestra_menus_del_dia branch did not render.'
      expect(response.body).to include('mas-productos-section'),
                               'Mas productos section MISSING — muestra_mas_productos_efectivo branch did not render.'
    end
  end

  def next_weekday(date = Date.current + 1.day)
    date += 1.day while date.saturday? || date.sunday?
    date
  end

  def build_pedido(tienda:, estado_id:, fecha: next_weekday, grp: nil)
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: estado_id,
                       fecha: fecha, autor: cliente_user, usuario: cliente_user,
                       pedido_multiple_id: grp&.id)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    p
  end
end
