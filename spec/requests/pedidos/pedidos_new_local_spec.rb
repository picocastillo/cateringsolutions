require 'rails_helper'

RSpec.describe 'PedidosController#new sets local for multi-local tiendas', type: :request do
  let(:tienda) do
    create(:tienda, nombre: 'Tienda Carrito MultiLocal',
                    multiple_locales: true, carrito_de_compras: true)
  end
  let(:local1) { create(:local, tienda: tienda, nombre: 'Local Primero') }
  let(:local2) { create(:local, tienda: tienda, nombre: 'Local Segundo') }
  let(:cliente_record) { create(:cliente, tienda: tienda, cuenta_corriente: true) }
  let(:cuenta) { create(:cuenta, cliente: cliente_record, cuenta_corriente_parcial: true) }
  let(:user) do
    local1 # force creation
    local2
    create(:usuario, :cliente,
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  before { login_as(user) }

  context 'when tienda has local_atencion_carrito configured' do
    before do
      tienda.update!(local_atencion_carrito: local2)
      tienda.reload
      allow_any_instance_of(ApplicationController).to receive(:tienda_activa).and_return(tienda)
    end

    it 'creates pedido with the configured local_atencion_carrito' do
      get new_pedido_path
      expect(response).to have_http_status(:redirect)

      pedido = Pedidos::Pedido.where(autor: user, tienda: tienda, venta_mostrador: false).last
      expect(pedido).to be_present
      expect(pedido.local).to eq local2
    end
  end

  context 'when tienda has no local_atencion_carrito (nil)' do
    it 'falls back to the first local of the tienda' do
      get new_pedido_path
      expect(response).to have_http_status(:redirect)

      pedido = Pedidos::Pedido.where(autor: user, tienda: tienda, venta_mostrador: false).last
      expect(pedido).to be_present
      expect(pedido.local).to eq tienda.locales.first
    end
  end
end
