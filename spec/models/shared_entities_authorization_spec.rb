require 'rails_helper'

# Step 5 of the shared-clientes migration: authorization rules for shared
# entities (Cliente, Usuario) must use the HABTM cliente↔tiendas link instead
# of the legacy `tienda == user.tienda_activa` / `tienda_cliente == ...` checks,
# so that an admin in tienda A can manage a cliente that is shared into tienda A.
RSpec.describe 'Shared entities authorization', type: :model do
  let(:tienda_a) { create(:tienda) }
  let(:tienda_b) { create(:tienda) }
  let(:admin) do
    u = create(:usuario, :admin, visualizando_tienda: tienda_a)
    u.tiendas << tienda_a unless u.tiendas.include?(tienda_a)
    u
  end
  let(:ability) { Ability.new(admin) }

  describe 'Clientes::Authorization' do
    it 'allows admin to manage a cliente whose legacy tienda matches' do
      cliente = create(:cliente, tienda: tienda_a)
      expect(ability.can?(:manage, cliente)).to be true
    end

    it 'allows admin to manage a cliente shared into the active tienda via HABTM' do
      cliente = create(:cliente, tienda: tienda_b)
      cliente.tiendas << tienda_a
      expect(ability.can?(:manage, cliente)).to be true
    end

    it 'forbids admin from managing a cliente not linked to the active tienda' do
      cliente = create(:cliente, tienda: tienda_b)
      expect(ability.can?(:manage, cliente)).to be false
    end
  end

  describe 'Usuarios::Authorization' do
    it 'allows admin to manage a cliente user whose cliente is shared into the active tienda' do
      cliente = create(:cliente, tienda: tienda_b)
      cliente.tiendas << tienda_a
      cuenta = create(:cuenta, cliente: cliente)
      cliente_user = create(:usuario, cuenta: cuenta, tienda_cliente: tienda_b, tipo_usuario_id: 1)

      expect(ability.can?(:manage, cliente_user)).to be true
    end

    it 'forbids admin from managing a cliente user whose cliente is NOT linked to the active tienda' do
      cliente = create(:cliente, tienda: tienda_b)
      cuenta = create(:cuenta, cliente: cliente)
      cliente_user = create(:usuario, cuenta: cuenta, tienda_cliente: tienda_b, tipo_usuario_id: 1)

      expect(ability.can?(:manage, cliente_user)).to be false
    end

    it 'still allows admin to manage another admin user via the usuarios_tiendas link' do
      other_admin = create(:usuario, :admin, visualizando_tienda: tienda_a)
      other_admin.tiendas << tienda_a
      expect(ability.can?(:manage, other_admin)).to be true
    end
  end
end
