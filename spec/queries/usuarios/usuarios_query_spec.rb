require 'rails_helper'

# Step 2 of the shared-clientes migration: the admin Usuarios index must filter
# by clientes_tiendas linkage instead of (or in addition to) the legacy
# usuarios.tienda_cliente_id column. This way, even after clientes become
# global, an admin still only sees the cliente users belonging to clientes that
# are linked to their active tienda.
RSpec.describe Usuarios::UsuariosQuery do
  let(:tienda_a) { create(:tienda) }
  let(:tienda_b) { create(:tienda) }
  let(:admin) do
    u = create(:usuario, :admin, visualizando_tienda: tienda_a)
    u.tiendas << tienda_a unless u.tiendas.include?(tienda_a)
    u
  end

  describe 'cliente users scoping' do
    it 'includes a cliente user whose cliente is linked to the active tienda' do
      cliente = create(:cliente, tienda: tienda_a)
      cuenta  = create(:cuenta, cliente: cliente)
      cli_user = create(:usuario, cuenta: cuenta, tienda_cliente: tienda_a, login: "user-a-#{SecureRandom.hex(3)}")

      results = described_class.new(user: admin).relation
      expect(results).to include(cli_user)
    end

    it 'excludes a cliente user whose cliente is only linked to a different tienda' do
      cliente = create(:cliente, tienda: tienda_b)
      cuenta  = create(:cuenta, cliente: cliente)
      foreign = create(:usuario, cuenta: cuenta, tienda_cliente: tienda_b, login: "user-b-#{SecureRandom.hex(3)}")

      results = described_class.new(user: admin).relation
      expect(results).not_to include(foreign)
    end

    it 'includes a shared cliente user once their cliente is linked to the active tienda' do
      # Cliente lives in tienda_b legacy but is shared into tienda_a.
      shared_cliente = create(:cliente, tienda: tienda_b)
      shared_cliente.tiendas << tienda_a
      cuenta = create(:cuenta, cliente: shared_cliente)
      shared_user = create(:usuario, cuenta: cuenta, tienda_cliente: tienda_b, login: "shared-#{SecureRandom.hex(3)}")

      results = described_class.new(user: admin).relation
      expect(results).to include(shared_user)
    end

    it 'still includes pure admin users (cuenta_id is null) regardless of linkage' do
      other_admin = create(:usuario, :admin, login: "admin-#{SecureRandom.hex(3)}")
      other_admin.tiendas << tienda_a

      results = described_class.new(user: admin).relation
      expect(results).to include(other_admin)
    end
  end
end
