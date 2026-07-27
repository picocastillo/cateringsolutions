require 'rails_helper'

# Request specs for PedidosMultiplesController#finalizar_multiple.
# Covers the validation logic added in the multi-date group ordering feature.
RSpec.describe 'PedidosMultiplesController#finalizar_multiple', type: :request do
  let!(:tienda) do
    create(:tienda, carrito_de_compras: true, maneja_stock: false, horarios_de_entrega: false)
  end
  let!(:pedido1) { make_pedido(fecha: Date.current + 1.day) }
  let!(:pedido2) { make_pedido(fecha: Date.current + 2.days) }
  let!(:cliente) do
    create(:cliente, tienda: tienda, cuenta_corriente: true, horarios_de_entrega: false,
                     usuario_puede_elegir_cuenta: false, permitir_envios_a_domicilio: false)
  end
  let!(:cuenta) { create(:cuenta, cliente: cliente, cuenta_corriente_parcial: true) }
  let!(:usuario) do
    create(:usuario, :admin, cuenta: cuenta, tienda_cliente: tienda,
                             visualizando_tienda: tienda).tap do |u|
      u.tiendas << tienda unless u.tiendas.include?(tienda)
    end
  end
  let!(:categoria) { create(:categoria, nombre: 'Cat FM', tienda: tienda, stock_activo: false) }
  let!(:producto)  { create(:producto, tienda: tienda, categoria: categoria) }
  let!(:grupo)     { Pedidos::PedidoMultiple.create!(usuario: usuario) }

  def make_pedido(fecha: Date.current + 1.day, grp: grupo)
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: fecha, autor: usuario, usuario: usuario,
                       pedido_multiple_id: grp.id)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    ps = Productos::ProductoSolicitado.new(pedido: p, producto: producto,
                                           cantidad: 1, precio_unitario: 50.0)
    ps.save(validate: false)
    p
  end

  before do
    create(:precio, :for_cliente, producto: producto, cliente: cliente,
                                  importe: 50, fecha_desde: Time.zone.today)
    login_as(usuario)
    allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante).and_return(true)
  end

  describe 'happy path — no turno required, no enviar_a required' do
    it 'redirects to pedidos_path with a success notice' do
      post finalizar_multiple_pedido_multipl_path(grupo)

      expect(response).to redirect_to(pedidos_path)
      follow_redirect!
      expect(response.body).to include('finalizados correctamente')
    end

    it 'transitions all pending pedidos to estado aceptado (2)' do
      post finalizar_multiple_pedido_multipl_path(grupo)

      expect(pedido1.reload.estado_id).to eq(2)
      expect(pedido2.reload.estado_id).to eq(2)
    end
  end

  describe 'when no pending pedidos exist' do
    before do
      pedido1.update_column(:estado_id, 2)
      pedido2.update_column(:estado_id, 2)
    end

    it 'redirects back to resumen with alert' do
      post finalizar_multiple_pedido_multipl_path(grupo)

      expect(response).to redirect_to(resumen_pedido_multipl_path(grupo))
      follow_redirect!
      expect(response.body).to include('No hay pedidos pendientes')
    end
  end

  describe 'turno_entrega validation' do
    let!(:turno)       { create(:turno_entrega, :almuerzo) }
    let!(:other_turno) { create(:turno_entrega) }

    before { create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno) }

    context 'turno_entrega_id is blank and client has active turnos' do
      it 'redirects to resumen with error mentioning Turno de Entrega' do
        post finalizar_multiple_pedido_multipl_path(grupo)

        expect(response).to redirect_to(resumen_pedido_multipl_path(grupo))
        follow_redirect!
        expect(response.body).to include('Turno de Entrega')
      end

      it 'leaves pedidos in pendiente' do
        post finalizar_multiple_pedido_multipl_path(grupo)

        expect(pedido1.reload.estado_id).to eq(1)
        expect(pedido2.reload.estado_id).to eq(1)
      end
    end

    context 'turno_entrega_id belongs to a different client' do
      before do
        pedido1.update_column(:turno_entrega_id, other_turno.id)
        pedido2.update_column(:turno_entrega_id, other_turno.id)
      end

      it 'redirects to resumen with unavailable-turno error' do
        post finalizar_multiple_pedido_multipl_path(grupo)

        expect(response).to redirect_to(resumen_pedido_multipl_path(grupo))
        follow_redirect!
        expect(response.body).to include('turno de entrega seleccionado no está disponible')
      end
    end

    context 'turno_entrega_id belongs to the client' do
      before do
        pedido1.update_column(:turno_entrega_id, turno.id)
        pedido2.update_column(:turno_entrega_id, turno.id)
      end

      it 'accepts all pedidos' do
        post finalizar_multiple_pedido_multipl_path(grupo)

        expect(response).to redirect_to(pedidos_path)
        expect(pedido1.reload.estado_id).to eq(2)
        expect(pedido2.reload.estado_id).to eq(2)
      end
    end
  end

  describe 'direccion_envio validation (envio_a_domicilio)' do
    before do
      cliente.update_column(:permitir_envios_a_domicilio, true)
      pedido1.update_columns(envio_a_domicilio: true, direccion_envio: nil)
      pedido2.update_columns(envio_a_domicilio: true, direccion_envio: nil)
    end

    it 'redirects when direccion_envio is blank' do
      post finalizar_multiple_pedido_multipl_path(grupo)

      expect(response).to redirect_to(resumen_pedido_multipl_path(grupo))
      follow_redirect!
      expect(response.body).to include('dirección de envío')
    end

    context 'direccion_envio is filled' do
      before do
        pedido1.update_column(:direccion_envio, 'Av. Siempre Viva 742')
        pedido2.update_column(:direccion_envio, 'Av. Siempre Viva 742')
      end

      it 'accepts the pedidos' do
        post finalizar_multiple_pedido_multipl_path(grupo)

        expect(response).to redirect_to(pedidos_path)
        expect(pedido1.reload.estado_id).to eq(2)
      end
    end
  end

  describe 'error messages include the pedido fecha' do
    let!(:turno) { create(:turno_entrega) }

    before { create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno) }

    it 'prefixes each error with the pedido date in short format' do
      post finalizar_multiple_pedido_multipl_path(grupo)

      follow_redirect!
      expect(response.body).to include(I18n.l(pedido1.fecha, format: :short))
    end
  end

  describe 'authorization' do
    it 'allows admin to access another user\'s grupo (admins have broad read access)' do
      other = create(:usuario, :admin, tienda_cliente: tienda, visualizando_tienda: tienda).tap do |u|
        u.tiendas << tienda
      end
      foreign_grupo = Pedidos::PedidoMultiple.create!(usuario: other)
      # Create at least one pedido in it so finalizar_multiple redirects to pedidos_path
      # instead of resumen (no pending pedidos after group is empty)
      post finalizar_multiple_pedido_multipl_path(foreign_grupo)
      expect(response).to redirect_to(resumen_pedido_multipl_path(foreign_grupo))
    end

    it 'denies cliente access to another user\'s grupo' do
      other_cliente_user = create(:usuario, :cliente, tienda_cliente: tienda, visualizando_tienda: tienda,
                                                      cuenta: cuenta).tap do |u|
        u.tiendas << tienda
      end
      Pedidos::PedidoMultiple.create!(usuario: other_cliente_user)

      login_as(other_cliente_user)
      post finalizar_multiple_pedido_multipl_path(grupo)
      expect(response).to have_http_status(403)
    end
  end
end
