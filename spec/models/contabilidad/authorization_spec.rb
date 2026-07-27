require 'rails_helper'

RSpec.describe Contabilidad::Authorization do
  let(:tienda) { create(:tienda) }

  describe 'authorization class' do
    it 'inherits from Ability::Subrules' do
      expect(described_class.superclass).to eq(Ability::Subrules)
    end

    it 'defines add_rules method' do
      expect(described_class.instance_methods).to include(:add_rules)
    end
  end

  describe 'admin permissions' do
    let(:admin_user) do
      create(:usuario, :admin, visualizando_tienda: tienda).tap do |u|
        u.tiendas << tienda unless u.tiendas.include?(tienda)
      end
    end
    let(:ability) { Ability.new(admin_user) }

    it 'can manage Movimiento for own tienda' do
      movimiento = Contabilidad::Movimiento.new(tienda: tienda)
      expect(ability.can?(:manage, movimiento)).to be true
    end

    it 'cannot manage Movimiento for other tienda' do
      other_tienda = create(:tienda)
      movimiento = Contabilidad::Movimiento.new(tienda: other_tienda)
      expect(ability.can?(:manage, movimiento)).to be false
    end
  end

  describe 'non-admin with gestiona_movimientos role' do
    let(:user) do
      create(:usuario, visualizando_tienda: tienda).tap do |u|
        u.tiendas << tienda unless u.tiendas.include?(tienda)
        rol = Usuarios::Rol.find_or_create_by(nombre: 'gestiona_movimientos')
        u.roles << rol unless u.roles.include?(rol)
      end
    end
    let(:ability) { Ability.new(user) }

    it 'can index Movimiento' do
      expect(ability.can?(:index, Contabilidad::Movimiento)).to be true
    end

    it 'can json_index Movimiento' do
      expect(ability.can?(:json_index, Contabilidad::Movimiento)).to be true
    end

    it 'can change Movimiento for own tienda' do
      movimiento = Contabilidad::Movimiento.new(tienda: tienda)
      expect(ability.can?(:change, movimiento)).to be true
    end

    it 'cannot xls_index Movimiento' do
      expect(ability.can?(:xls_index, Contabilidad::Movimiento)).to be false
    end
  end

  describe 'non-admin with administrador_empresa role' do
    let(:user) do
      create(:usuario, visualizando_tienda: tienda).tap do |u|
        u.tiendas << tienda unless u.tiendas.include?(tienda)
        rol = Usuarios::Rol.find_or_create_by(nombre: 'administrador_empresa')
        u.roles << rol unless u.roles.include?(rol)
      end
    end
    let(:ability) { Ability.new(user) }

    it 'can index Movimiento' do
      expect(ability.can?(:index, Contabilidad::Movimiento)).to be true
    end

    it 'cannot xls_index Movimiento' do
      expect(ability.can?(:xls_index, Contabilidad::Movimiento)).to be false
    end
  end
end
