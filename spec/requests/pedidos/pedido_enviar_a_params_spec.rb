require 'rails_helper'

# Tests that PATCH /pedidos/:id now accepts :enviar_a_id and :direccion_envio
# through the strong-parameters whitelist (added alongside :turno_entrega_id).
RSpec.describe 'PedidosController PATCH update — enviar_a_id / direccion_envio params', type: :request do
  let!(:tienda) do
    create(:tienda, carrito_de_compras: true, maneja_stock: false)
  end
  let!(:cliente) do
    create(:cliente, tienda: tienda, cuenta_corriente: false,
                     usuario_puede_elegir_cuenta: true,
                     permitir_envios_a_domicilio: true)
  end
  let!(:cuenta) { create(:cuenta, cliente: cliente, cuenta_corriente_parcial: nil) }
  let!(:cuenta2) do
    create(:cuenta, cliente: cliente, nombre: 'Cuenta Secundaria')
  end
  let!(:usuario) do
    create(:usuario, :admin, cuenta: cuenta, tienda_cliente: tienda,
                             visualizando_tienda: tienda).tap do |u|
      u.tiendas << tienda unless u.tiendas.include?(tienda)
    end
  end
  let!(:pedido) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1,
                       fecha: Date.current + 1.day, autor: usuario, usuario: usuario)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    p
  end

  before { login_as(usuario) }

  describe 'PATCH with enviar_a_id (switch to another account)' do
    it 'updates the cuenta on the pedido' do
      patch pedido_path(pedido), params: { pedido: { enviar_a_id: cuenta2.id } }

      expect(response).not_to have_http_status(:bad_request)
      pedido.reload
      expect(pedido.cuenta_id).to eq(cuenta2.id)
    end
  end

  describe 'PATCH with enviar_a_id = -1 (domicilio particular)' do
    it 'sets envio_a_domicilio on the pedido' do
      patch pedido_path(pedido),
            params: { pedido: { enviar_a_id: -1, direccion_envio: 'Calle Falsa 123' } }

      expect(response).not_to have_http_status(:bad_request)
      pedido.reload
      expect(pedido.envio_a_domicilio).to be true
      expect(pedido.direccion_envio).to eq('Calle Falsa 123')
    end
  end

  describe 'PATCH with direccion_envio alone (ignored when envio_a_domicilio is false)' do
    it 'does not raise UnpermittedParameters' do
      expect do
        patch pedido_path(pedido),
              params: { pedido: { direccion_envio: 'Nueva direccion' } }
      end.not_to raise_error
    end
  end
end
