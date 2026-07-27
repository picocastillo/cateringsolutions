require 'rails_helper'

# Tiendas::Authorization — regular admin can no longer :manage Tienda;
# only super_admin (id == 1, stubbed here) can. Admin retains :cambiar_tienda
# for their own tiendas only.
RSpec.describe 'Tiendas::Authorization', type: :model do
  let(:tienda_a) { create(:tienda) }
  let(:tienda_b) { create(:tienda) }

  let(:admin) do
    create(:usuario, :admin, visualizando_tienda: tienda_a).tap do |u|
      u.tiendas << tienda_a unless u.tiendas.include?(tienda_a)
    end
  end

  describe 'super_admin (stubbed)' do
    let(:ability) do
      allow(admin).to receive(:super_admin?).and_return(true)
      Ability.new(admin)
    end

    it 'can manage any Tienda' do
      expect(ability.can?(:manage, tienda_a)).to be true
      expect(ability.can?(:manage, tienda_b)).to be true
    end

    it 'can cambiar_tienda' do
      expect(ability.can?(:cambiar_tienda, tienda_a)).to be true
    end
  end

  describe 'regular admin (not super_admin)' do
    let(:ability) { Ability.new(admin) }

    it 'cannot manage the Tienda they belong to' do
      expect(ability.can?(:manage, tienda_a)).to be false
    end

    it 'cannot manage a Tienda they do not belong to' do
      expect(ability.can?(:manage, tienda_b)).to be false
    end

    it 'can cambiar_tienda for their own tienda' do
      expect(ability.can?(:cambiar_tienda, tienda_a)).to be true
    end

    it 'cannot cambiar_tienda for a tienda they do not belong to' do
      expect(ability.can?(:cambiar_tienda, tienda_b)).to be false
    end
  end

  describe 'cliente user' do
    let(:cliente_user) do
      cliente = create(:cliente, tienda: tienda_a)
      cuenta  = create(:cuenta, cliente: cliente)
      create(:usuario, :cliente, cuenta: cuenta, tienda_cliente: tienda_a,
                                 visualizando_tienda: tienda_a)
    end

    let(:ability) { Ability.new(cliente_user) }

    it 'can cambiar_tienda_activa' do
      expect(ability.can?(:cambiar_tienda_activa, Tiendas::Tienda)).to be true
    end

    it 'cannot manage any Tienda' do
      expect(ability.can?(:manage, tienda_a)).to be false
    end
  end
end
