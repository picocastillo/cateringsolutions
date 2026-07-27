require 'rails_helper'

RSpec.describe 'TiendasController#cambiar_tienda_activa for admins', type: :request do
  let(:tienda_a) { create(:tienda) }
  let(:tienda_b) { create(:tienda) }
  let(:tienda_x) { create(:tienda) }

  let!(:admin) do
    u = create(:usuario, :admin,
               login: "admin_switch_#{SecureRandom.hex(3)}",
               password: 'admin123',
               password_confirmation: 'admin123',
               visualizando_tienda: tienda_a)
    u.tiendas << tienda_b unless u.tiendas.include?(tienda_b)
    u
  end

  before do
    host! tienda_a.dominio
    post '/public', params: { username: admin.login, password: 'admin123' }
  end

  it 'updates visualizando_tienda_id for admin switching to a tienda in their list' do
    expect do
      post '/tiendas/cambiar_tienda_activa',
           params: { tienda_activa_id: tienda_b.id },
           headers: { 'Accept' => 'application/json' }
    end.to change { admin.reload.visualizando_tienda_id }.from(tienda_a.id).to(tienda_b.id)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['redirect_url']).to eq('/inicio')
  end

  it 'rejects switching to a tienda not in the admin tiendas list' do
    expect do
      post '/tiendas/cambiar_tienda_activa',
           params: { tienda_activa_id: tienda_x.id },
           headers: { 'Accept' => 'application/json' }
    end.not_to(change { admin.reload.visualizando_tienda_id })

    expect(response).to have_http_status(:forbidden)
  end
end
