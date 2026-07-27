require 'rails_helper'

# Step 3 of the shared-clientes migration: login through the public sessions
# endpoint must reject cliente users when (a) the active tienda has
# permitir_login_clientes = false or (b) the user's cliente is not linked to
# the active tienda.
RSpec.describe 'PublicsController login guard', type: :request do
  let(:tienda) { create(:tienda, dominio: 'login.example.com') }
  let(:other_tienda) { create(:tienda, dominio: 'otro.example.com') }
  let(:cliente) { create(:cliente, tienda: tienda) }
  let(:cuenta)  { create(:cuenta, cliente: cliente) }

  let!(:cliente_user) do
    u = build(:usuario, cuenta: cuenta, tienda_cliente: tienda, tipo_usuario_id: 1,
                        login: "client-#{SecureRandom.hex(3)}")
    u.password = u.password_confirmation = 'secret123'
    u.crypted_password = nil
    u.salt = nil
    u.save!
    u
  end

  before { host! tienda.dominio }

  context 'when the active tienda allows cliente logins' do
    it 'logs the cliente in' do
      post '/public', params: { username: cliente_user.login, password: 'secret123' }
      expect(session[:user_id]).to eq cliente_user.id
    end
  end

  context 'when the active tienda has permitir_login_clientes = false' do
    before { tienda.update!(permitir_login_clientes: false) }

    it 'refuses to log the cliente in' do
      post '/public', params: { username: cliente_user.login, password: 'secret123' }
      expect(session[:user_id]).to be_nil
    end

    it 'still allows admin login (admins are not gated by the flag)' do
      admin = create(:usuario, :admin, visualizando_tienda: tienda,
                                       login: "adm-#{SecureRandom.hex(3)}")
      admin.tiendas << tienda
      admin.password = admin.password_confirmation = 'secret123'
      admin.crypted_password = nil
      admin.salt = nil
      admin.save!

      post '/public', params: { username: admin.login, password: 'secret123' }
      expect(session[:user_id]).to eq admin.id
    end
  end

  context 'when the cliente is not linked to the active tienda' do
    before { host! other_tienda.dominio }

    it 'refuses to log the cliente in' do
      post '/public', params: { username: cliente_user.login, password: 'secret123' }
      expect(session[:user_id]).to be_nil
    end
  end

  context 'when the cliente is shared into the active tienda' do
    before do
      cliente.tiendas << other_tienda
      host! other_tienda.dominio
    end

    it 'allows the cliente to log in on the additional tienda' do
      post '/public', params: { username: cliente_user.login, password: 'secret123' }
      expect(session[:user_id]).to eq cliente_user.id
    end
  end
end
