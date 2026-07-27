require 'rails_helper'

RSpec.describe Clientes::ClientesParaAcQuery do
  let(:tienda) { create(:tienda) }
  let(:usuario) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let!(:cliente1) { create(:cliente, tienda: tienda, nombre: 'Panaderia San Martin', email: 'panaderia@test.com') }
  let!(:cliente2) { create(:cliente, tienda: tienda, nombre: 'Cafeteria Del Sol', email: 'cafe@test.com') }

  before do
    usuario.tiendas << tienda unless usuario.tiendas.include?(tienda)
  end

  describe 'validations' do
    it 'requires q' do
      query = described_class.new(user: usuario)
      expect(query).not_to be_valid
    end

    it 'requires minimum length of 2' do
      query = described_class.new(user: usuario, q: 'A')
      expect(query).not_to be_valid
    end
  end

  describe '#relation' do
    it 'searches by nombre' do
      query = described_class.new(user: usuario, q: 'Panaderia')
      expect(query.relation).to include(cliente1)
      expect(query.relation).not_to include(cliente2)
    end

    it 'searches by email' do
      query = described_class.new(user: usuario, q: 'cafe')
      expect(query.relation).to include(cliente2)
      expect(query.relation).not_to include(cliente1)
    end

    it 'searches by cuit (numeric)' do
      query = described_class.new(user: usuario, q: cliente1.cuit[0..4])
      expect(query.relation).to include(cliente1)
    end

    it 'excludes discontinued clientes' do
      cliente1.discontinue!
      query = described_class.new(user: usuario, q: 'Panaderia')
      expect(query.relation).not_to include(cliente1)
    end

    it 'only returns clientes from user tienda' do
      other_tienda = create(:tienda)
      other_cliente = create(:cliente, tienda: other_tienda, nombre: 'Panaderia Otra')

      query = described_class.new(user: usuario, q: 'Panaderia')
      expect(query.relation).to include(cliente1)
      expect(query.relation).not_to include(other_cliente)
    end

    it 'orders by nombre' do
      described_class.new(user: usuario, q: 'a') # at least 2 chars needed
      # Both names contain 'a', but need 2-char minimum
      query = described_class.new(user: usuario, q: 'er')
      results = query.relation.to_a
      expect(results).to eq results.sort_by(&:nombre)
    end
  end
end
