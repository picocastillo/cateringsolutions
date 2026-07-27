require 'rails_helper'

# Step 3 of the shared-clientes migration: Usuario must expose the set of
# tiendas where it is allowed to log in (cliente users derive this from their
# cliente's HABTM links + the per-tienda permitir_login_clientes flag; admin
# users derive it from their existing usuarios_tiendas join).
RSpec.describe Usuarios::Usuario, type: :model do
  let(:tienda_a) { create(:tienda) }
  let(:tienda_b) { create(:tienda) }

  describe '#tiendas_disponibles' do
    context 'for a cliente user' do
      let(:cliente) { create(:cliente, tienda: tienda_a) }
      let(:cuenta)  { create(:cuenta, cliente: cliente) }
      let(:user)    { create(:usuario, cuenta: cuenta, tienda_cliente: tienda_a, tipo_usuario_id: 1) }

      it 'returns the cliente tiendas where login is allowed' do
        expect(user.tiendas_disponibles).to contain_exactly(tienda_a)
      end

      it 'includes additional tiendas the cliente is shared into' do
        cliente.tiendas << tienda_b
        expect(user.tiendas_disponibles).to contain_exactly(tienda_a, tienda_b)
      end

      it 'excludes tiendas where permitir_login_clientes is false' do
        cliente.tiendas << tienda_b
        tienda_b.update!(permitir_login_clientes: false)
        expect(user.tiendas_disponibles).to contain_exactly(tienda_a)
      end

      it 'returns an empty relation when the user has no cuenta' do
        orphan = build(:usuario, cuenta: nil, tienda_cliente: nil, tipo_usuario_id: 1)
        expect(orphan.tiendas_disponibles).to be_empty
      end
    end

    context 'for an admin user' do
      it 'returns the tiendas joined via usuarios_tiendas' do
        admin = create(:usuario, :admin, visualizando_tienda: tienda_a)
        admin.tiendas << tienda_b
        expect(admin.tiendas_disponibles).to contain_exactly(tienda_a, tienda_b)
      end

      it 'is unaffected by permitir_login_clientes (admin login is not gated by it)' do
        admin = create(:usuario, :admin, visualizando_tienda: tienda_a)
        tienda_a.update!(permitir_login_clientes: false)
        expect(admin.tiendas_disponibles).to include(tienda_a)
      end
    end
  end

  describe '#puede_loguearse_en?' do
    let(:cliente) { create(:cliente, tienda: tienda_a) }
    let(:cuenta)  { create(:cuenta, cliente: cliente) }
    let(:user)    { create(:usuario, cuenta: cuenta, tienda_cliente: tienda_a, tipo_usuario_id: 1) }

    it 'returns true when the cliente is linked to the tienda and login is allowed' do
      expect(user.puede_loguearse_en?(tienda_a)).to be true
    end

    it 'returns false when the cliente is not linked to that tienda' do
      expect(user.puede_loguearse_en?(tienda_b)).to be false
    end

    it 'returns false when permitir_login_clientes is disabled on the target tienda' do
      tienda_a.update!(permitir_login_clientes: false)
      expect(user.puede_loguearse_en?(tienda_a)).to be false
    end

    it 'returns false when tienda is nil' do
      expect(user.puede_loguearse_en?(nil)).to be false
    end

    it 'returns true for admin users regardless of permitir_login_clientes' do
      admin = create(:usuario, :admin, visualizando_tienda: tienda_a)
      admin.tiendas << tienda_a
      tienda_a.update!(permitir_login_clientes: false)
      expect(admin.puede_loguearse_en?(tienda_a)).to be true
    end

    it 'returns false for admin users when they have no usuarios_tiendas link to that tienda' do
      admin = create(:usuario, :admin, visualizando_tienda: tienda_a)
      admin.tiendas << tienda_a
      expect(admin.puede_loguearse_en?(tienda_b)).to be false
    end
  end

  describe '.authenticate with a tienda' do
    let(:cliente) { create(:cliente, tienda: tienda_a) }
    let(:cuenta)  { create(:cuenta, cliente: cliente) }
    let!(:user) do
      u = build(:usuario, cuenta: cuenta, tienda_cliente: tienda_a, tipo_usuario_id: 1,
                          login: "alogin-#{SecureRandom.hex(3)}")
      u.password = u.password_confirmation = 'secret123'
      u.crypted_password = nil
      u.salt = nil
      u.save!
      u
    end

    it 'returns :ok when login matches and tienda is allowed' do
      result = described_class.authenticate(user.login, 'secret123', tienda_a)
      expect(result[:result]).to eq :ok
      expect(result[:user]).to eq user
    end

    it 'returns :tienda_no_autorizada when credentials are valid but tienda is blocked' do
      tienda_a.update!(permitir_login_clientes: false)
      result = described_class.authenticate(user.login, 'secret123', tienda_a)
      expect(result[:result]).to eq :tienda_no_autorizada
    end

    it 'returns :tienda_no_autorizada when cliente is not linked to that tienda' do
      result = described_class.authenticate(user.login, 'secret123', tienda_b)
      expect(result[:result]).to eq :tienda_no_autorizada
    end

    it 'still returns :wrong_credentials for bad password (tienda check is secondary)' do
      result = described_class.authenticate(user.login, 'wrong', tienda_a)
      expect(result[:result]).to eq :wrong_credentials
    end

    it 'is backwards-compatible when tienda is omitted (no tienda gating)' do
      tienda_a.update!(permitir_login_clientes: false)
      result = described_class.authenticate(user.login, 'secret123')
      expect(result[:result]).to eq :ok
    end
  end
end
