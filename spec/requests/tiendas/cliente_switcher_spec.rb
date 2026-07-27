require 'rails_helper'

# Step 6 of the shared-clientes migration: cliente users whose cliente is
# linked to multiple tiendas can switch their active tienda via the existing
# /tiendas/cambiar_tienda_activa endpoint. For clientes we update
# `tienda_cliente_id` (the column that drives `Usuario#tienda_activa` for
# clientes) and respond with a cross-domain redirect to the chosen tienda's
# /pedidos/new.
RSpec.describe 'TiendasController#cambiar_tienda_activa for clientes', type: :request do
  let(:tienda_a) { create(:tienda, dominio: 'a.example.com') }
  let(:tienda_b) { create(:tienda, dominio: 'b.example.com') }
  let(:tienda_x) { create(:tienda, dominio: 'x.example.com') }

  let(:cliente) { create(:cliente, tienda: tienda_a) }
  let(:cuenta)  { create(:cuenta, cliente: cliente) }

  let!(:cliente_user) do
    u = build(:usuario, cuenta: cuenta, tienda_cliente: tienda_a, tipo_usuario_id: 1,
                        login: "client-#{SecureRandom.hex(3)}")
    u.password = u.password_confirmation = 'secret123'
    u.crypted_password = nil
    u.salt = nil
    u.save!
    u
  end

  before do
    cliente.tiendas << tienda_b # cliente shared into B
    host! tienda_a.dominio
    post '/public', params: { username: cliente_user.login, password: 'secret123' }
  end

  it 'updates tienda_cliente_id when the cliente switches to a tienda they share' do
    expect do
      post '/tiendas/cambiar_tienda_activa', params: { tienda_activa_id: tienda_b.id }
    end.to change { cliente_user.reload.tienda_cliente_id }.from(tienda_a.id).to(tienda_b.id)
  end

  it 'redirects to the chosen tienda dominio for clientes' do
    post '/tiendas/cambiar_tienda_activa', params: { tienda_activa_id: tienda_b.id }
    expect(response).to redirect_to('/pedidos/new')
  end

  it 'rejects switching to a tienda the cliente is NOT linked to' do
    expect do
      post '/tiendas/cambiar_tienda_activa', params: { tienda_activa_id: tienda_x.id }
    end.not_to(change { cliente_user.reload.tienda_cliente_id })
    expect(response).to have_http_status(:forbidden)
  end

  it 'rejects switching to a tienda where permitir_login_clientes is false' do
    tienda_b.update!(permitir_login_clientes: false)
    expect do
      post '/tiendas/cambiar_tienda_activa', params: { tienda_activa_id: tienda_b.id }
    end.not_to(change { cliente_user.reload.tienda_cliente_id })
    expect(response).to have_http_status(:forbidden)
  end
end
