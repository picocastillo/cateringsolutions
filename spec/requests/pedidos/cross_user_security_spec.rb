require 'rails_helper'

# Regression specs for the 2026-05-17 MP $14,820 incident.
# Bug A: `vaciar_carrito_pendiente!` destroyed siblings belonging to OTHER
#        users in the same cuenta. The model now refuses to destroy pedidos
#        that are cobrado / estado>=3 / have pagos_electronicos, and the
#        controller filters siblings to current_user.id + estado_id=1.
# Bug B: `PedidoMultiple.abiertos` is cuenta-scoped. The controller used to
#        auto-attach a new shell to any open PM in the cuenta, so user X
#        joined user Y's group. Auto-attach is now strictly usuario-scoped.
RSpec.describe 'Pedidos cross-user security', type: :request do
  let!(:tienda) { create(:tienda, dominio: 'sec.example.com', carrito_de_compras: true, maneja_stock: false, horarios_de_entrega: false) }
  let!(:cliente) do
    create(:cliente, tiendas: [tienda], cuenta_corriente: true,
                     horarios_de_entrega: false, usuario_puede_elegir_cuenta: false,
                     permitir_envios_a_domicilio: false)
  end
  let!(:cuenta) { create(:cuenta, cliente: cliente, cuenta_corriente_parcial: true) }

  let!(:user_a) { make_user('user-a') }
  let!(:user_b) { make_user('user-b') }

  let!(:categoria) { create(:categoria, nombre: 'Cat', tienda: tienda, stock_activo: false) }
  let!(:producto)  { create(:producto, tienda: tienda, categoria: categoria) }

  before do
    create(:precio, :for_cliente, producto: producto, cliente: cliente,
                                  importe: 100, fecha_desde: Date.current - 1.day)
    host! tienda.dominio
  end

  describe 'Bug A — Vaciar Carrito must NOT destroy other users\' pedidos' do
    let!(:grupo) { Pedidos::PedidoMultiple.create!(usuario: user_a, cuenta: cuenta) }
    let!(:pedido_de_a) do
      p = build_pedido(autor: user_a, usuario: user_a, fecha: next_weekday, grp: grupo)
      p.update_columns(facturado: true, cobrado: true, estado_id: 3)
      p
    end
    let!(:pedido_de_b) { build_pedido(autor: user_b, usuario: user_b, fecha: next_weekday + 1.day, grp: grupo) }

    before do
      post '/public', params: { username: user_b.login, password: 'secret123' }
    end

    it 'does NOT destroy a sibling owned by another user (and paid)' do
      expect do
        post "/pedidos/#{pedido_de_b.id}/actualizar_desde_carrito",
             params: { vaciar_carrito: true, pedido: { observaciones_cliente: '' } },
             xhr: true
      end.not_to(change { Pedidos::Pedido.exists?(pedido_de_a.id) })
      expect(pedido_de_a.reload.cobrado).to be(true)
    end

    it 'still empties the current user\'s own pedido (resetea contenido)' do
      Productos::ProductoSolicitado.new(pedido: pedido_de_b, producto: producto,
                                        cantidad: 1, precio_unitario: 100.0).save(validate: false)
      expect do
        post "/pedidos/#{pedido_de_b.id}/actualizar_desde_carrito",
             params: { vaciar_carrito: true, pedido: { observaciones_cliente: '' } },
             xhr: true
      end.to change { pedido_de_b.reload.productos_solicitados.count }.from(1).to(0)
    end
  end

  describe 'Bug B — auto-attach must be strictly usuario-scoped' do
    let!(:grupo_de_a) { Pedidos::PedidoMultiple.create!(usuario: user_a, cuenta: cuenta) }
    let!(:pedido_de_a_en_grupo) do
      p = build_pedido(autor: user_a, usuario: user_a, fecha: next_weekday, grp: grupo_de_a)
      Productos::ProductoSolicitado.new(pedido: p, producto: producto,
                                        cantidad: 1, precio_unitario: 100.0).save(validate: false)
      p
    end

    before do
      post '/public', params: { username: user_b.login, password: 'secret123' }
    end

    it 'does NOT enroll user B\'s new shell into user A\'s open group' do
      expect { get '/pedidos/new' }.to change { Pedidos::Pedido.where(autor_id: user_b.id).count }.by(1)

      nuevo = Pedidos::Pedido.where(autor_id: user_b.id).order(:id).last
      expect(nuevo.pedido_multiple_id).to be_nil
      expect(grupo_de_a.pedidos.reload.pluck(:autor_id)).to eq([user_a.id])
    end
  end

  def make_user(login)
    u = build(:usuario, cuenta: cuenta, tienda_cliente: tienda, tipo_usuario_id: 1, login: login)
    u.password = u.password_confirmation = 'secret123'
    u.crypted_password = nil
    u.salt = nil
    u.save!
    u
  end

  def next_weekday(date = Date.current + 1.day)
    date += 1.day while date.saturday? || date.sunday?
    date
  end

  def build_pedido(autor:, usuario:, fecha:, grp: nil)
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: fecha, autor: autor, usuario: usuario)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    # Bypass pedido_multiple_owner_matches to simulate the legacy contaminated
    # state these specs are explicitly exercising (cross-user PM contamination).
    p.update_column(:pedido_multiple_id, grp.id) if grp
    p
  end
end
