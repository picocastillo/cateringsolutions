require 'rails_helper'

RSpec.describe Productos::Authorization do
  let(:tienda_sin_stock) { create(:tienda, maneja_stock: false) }
  let(:tienda_con_stock) { create(:tienda, maneja_stock: true) }

  describe 'authorization class' do
    it 'inherits from Ability::Subrules' do
      expect(described_class.superclass).to eq(Ability::Subrules)
    end

    it 'defines add_rules method' do
      expect(described_class.instance_methods).to include(:add_rules)
    end
  end

  describe 'admin permissions with maneja_stock: false' do
    let(:admin_user) do
      create(:usuario, :admin, visualizando_tienda: tienda_sin_stock).tap do |u|
        u.tiendas << tienda_sin_stock unless u.tiendas.include?(tienda_sin_stock)
      end
    end
    let(:ability) { Ability.new(admin_user) }

    it 'allows managing productos' do
      producto = create(:producto, tienda: tienda_sin_stock)
      expect(ability.can?(:manage, producto)).to be true
    end

    it 'does NOT allow managing stocks' do
      stock = create(:stock, tienda: tienda_sin_stock)
      expect(ability.can?(:manage, stock)).to be false
    end

    it 'does NOT allow xls export for stocks' do
      expect(ability.can?(:xls_index, Productos::Stock)).to be false
    end
  end

  describe 'admin permissions with maneja_stock: true' do
    let(:admin_user) do
      create(:usuario, :admin, visualizando_tienda: tienda_con_stock).tap do |u|
        u.tiendas << tienda_con_stock unless u.tiendas.include?(tienda_con_stock)
      end
    end
    let(:ability) { Ability.new(admin_user) }

    it 'allows managing productos' do
      producto = create(:producto, tienda: tienda_con_stock)
      expect(ability.can?(:manage, producto)).to be true
    end

    it 'allows managing stocks' do
      stock = create(:stock, tienda: tienda_con_stock)
      expect(ability.can?(:manage, stock)).to be true
    end

    it 'allows xls export for stocks' do
      expect(ability.can?(:xls_index, Productos::Stock)).to be true
    end

    it 'allows importing stocks' do
      expect(ability.can?(:import, Productos::Stock)).to be true
    end
  end
end
