require 'rails_helper'

RSpec.describe Clientes::CuentasParaAcQuery do
  let(:tienda) { create(:tienda) }
  let(:usuario) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let(:cliente) { create(:cliente, tienda: tienda, nombre: 'Restaurant ABC') }
  let!(:cuenta1) { create(:cuenta, cliente: cliente, nombre: 'Sede Central', nro: '1001') }
  let!(:cuenta2) { create(:cuenta, cliente: cliente, nombre: 'Sucursal Norte', nro: '2002') }

  before do
    usuario.tiendas << tienda unless usuario.tiendas.include?(tienda)
  end

  describe 'validations' do
    it 'requires q' do
      query = described_class.new(user: usuario)
      expect(query).not_to be_valid
      expect(query.errors[:q]).to be_present
    end

    it 'requires minimum length of 2' do
      query = described_class.new(user: usuario, q: 'A')
      expect(query).not_to be_valid
    end
  end

  describe '#relation' do
    it 'searches by cuenta nombre' do
      query = described_class.new(user: usuario, q: 'Central')
      expect(query.relation).to include(cuenta1)
      expect(query.relation).not_to include(cuenta2)
    end

    it 'searches by cliente nombre' do
      query = described_class.new(user: usuario, q: 'Restaurant')
      results = query.relation
      expect(results).to include(cuenta1, cuenta2)
    end

    it 'searches by nro' do
      query = described_class.new(user: usuario, q: '1001')
      expect(query.relation).to include(cuenta1)
      expect(query.relation).not_to include(cuenta2)
    end

    it 'excludes discontinued clientes' do
      cliente.discontinue!
      query = described_class.new(user: usuario, q: 'Central')
      expect(query.relation).not_to include(cuenta1)
    end

    it 'excludes discontinued cuentas' do
      cuenta1.discontinue!
      query = described_class.new(user: usuario, q: 'Central')
      expect(query.relation).not_to include(cuenta1)
    end

    it 'only returns cuentas from user tienda' do
      other_tienda = create(:tienda)
      other_cliente = create(:cliente, tienda: other_tienda, nombre: 'Restaurant XYZ')
      other_cuenta = create(:cuenta, cliente: other_cliente, nombre: 'Sede Central')

      query = described_class.new(user: usuario, q: 'Central')
      expect(query.relation).to include(cuenta1)
      expect(query.relation).not_to include(other_cuenta)
    end

    it 'orders by nombre' do
      query = described_class.new(user: usuario, q: cliente.nombre[0..3])
      results = query.relation.to_a
      expect(results).to eq results.sort_by(&:nombre)
    end
  end
end
