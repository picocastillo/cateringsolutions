require 'rails_helper'

RSpec.describe 'Pedidos::ConfirmationController', type: :request do
  let(:tienda) { create(:tienda, nombre: 'Tienda Confirmation', carrito_de_compras: true) }
  let(:cliente_record) { create(:cliente, tienda: tienda) }
  let(:cuenta) { create(:cuenta, cliente: cliente_record, cuenta_corriente_parcial: nil) }
  let(:user) do
    create(:usuario, :cliente,
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let(:pedido) do
    p = Pedidos::Pedido.new(
      autor: user, usuario: user, cuenta: cuenta,
      tienda: tienda, fecha: Date.current, estado_id: 1
    )
    p.no_validar_fecha = true
    p.save!
    p
  end

  before { login_as(user) }

  describe 'GET /confirmation/:id' do
    it 'finds pedido by confirmation_token without requiring tienda_activa match' do
      get confirmation_path(pedido.confirmation_token, pedido_id: pedido.id)

      expect(response).to redirect_to(pedido_path(pedido))
    end

    it 'rejects request with invalid confirmation_token' do
      get confirmation_path('INVALID_TOKEN', pedido_id: pedido.id)
      expect(response.status).to eq(403)
    end
  end
end
