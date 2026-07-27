require 'rails_helper'

RSpec.describe Clientes::ClientesQuery do
  let(:tienda) { create(:tienda) }
  let(:usuario) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let!(:cliente1) { create(:cliente, tienda: tienda, nombre: 'Restaurante Norte', email: 'norte@test.com', horario_corte_pedidos: '12:00') }
  let!(:cliente2) { create(:cliente, tienda: tienda, nombre: 'Catering Sur', email: 'sur@test.com', horario_corte_pedidos: '18:00') }

  before do
    usuario.tiendas << tienda unless usuario.tiendas.include?(tienda)
  end

  describe 'validations' do
    it 'requires user' do
      query = described_class.new
      expect(query).not_to be_valid
      expect(query.errors[:user]).to be_present
    end
  end

  describe '#relation' do
    it 'returns clientes for user tienda' do
      other_tienda = create(:tienda)
      create(:cliente, tienda: other_tienda, nombre: 'Other Client')

      query = described_class.new(user: usuario)
      results = query.relation
      expect(results).to include(cliente1, cliente2)
      expect(results.to_a.length).to eq 2
    end

    it 'filters by cliente_ids as String' do
      query = described_class.new(user: usuario, cliente_ids: cliente1.id.to_s)
      expect(query.relation).to include(cliente1)
      expect(query.relation).not_to include(cliente2)
    end

    it 'filters by cliente_ids as Array' do
      query = described_class.new(user: usuario, cliente_ids: [cliente1.id])
      expect(query.relation).to include(cliente1)
      expect(query.relation).not_to include(cliente2)
    end

    it 'filters by cuenta_ids' do
      cuenta = create(:cuenta, cliente: cliente1)
      query = described_class.new(user: usuario, cuenta_ids: [cuenta.id])
      expect(query.relation).to include(cliente1)
      expect(query.relation).not_to include(cliente2)
    end

    it 'filters by cuit' do
      query = described_class.new(user: usuario, cuit: cliente1.cuit[0..4])
      expect(query.relation).to include(cliente1)
    end

    it 'filters by email' do
      query = described_class.new(user: usuario, email: 'sur@')
      expect(query.relation).to include(cliente2)
      expect(query.relation).not_to include(cliente1)
    end

    it 'filters by activo = active' do
      cliente2.discontinue!

      query = described_class.new(user: usuario, activo: 'active')
      expect(query.relation).to include(cliente1)
      expect(query.relation).not_to include(cliente2)
    end

    it 'filters by activo = inactive' do
      cliente2.discontinue!

      query = described_class.new(user: usuario, activo: 'false')
      expect(query.relation).to include(cliente2)
      expect(query.relation).not_to include(cliente1)
    end

    it 'filters by horario_corte_cliente_ids' do
      query = described_class.new(user: usuario, horario_corte_cliente_ids: ['18:00'])
      expect(query.relation).to include(cliente2)
      expect(query.relation).not_to include(cliente1)
    end

    it 'filters by horario_corte_cuenta_ids' do
      cuenta = create(:cuenta, cliente: cliente1)
      cuenta.update_column(:horario_corte_pedidos, '10:00')

      query = described_class.new(user: usuario, horario_corte_cuenta_ids: ['10:00'])
      expect(query.relation).to include(cliente1)
      expect(query.relation).not_to include(cliente2)
    end

    it 'filters by horarios_de_corte_ids using effective hora_corte' do
      cuenta = create(:cuenta, cliente: cliente1)
      cuenta.update_column(:horario_corte_pedidos, '10:00')

      query = described_class.new(user: usuario, horarios_de_corte_ids: ['10:00'])
      expect(query.relation).to include(cliente1)
    end

    it 'handles horarios_de_corte_ids as String' do
      query = described_class.new(user: usuario, horarios_de_corte_ids: '12:00')
      expect(query.relation).to include(cliente1)
    end

    it 'orders by nombre' do
      results = described_class.new(user: usuario).relation
      expect(results.first.nombre).to be <= results.last.nombre
    end

    it 'returns distinct results' do
      # Create two cuentas for same cliente to verify distinct
      create(:cuenta, cliente: cliente1)
      create(:cuenta, cliente: cliente1)
      query = described_class.new(user: usuario)
      # Should not have duplicates
      expect(query.relation.to_a.length).to eq query.relation.to_a.uniq.length
    end

    # Step 2 — shared-clientes migration: query must scope by the clientes_tiendas
    # HABTM, not by the legacy clientes.tienda_id column. This guarantees that
    # once a cliente is shared across tiendas (linked via the join table) it shows
    # up in the index of every linked tienda, even if its legacy tienda_id no
    # longer matches.
    it 'returns clientes linked via clientes_tiendas to the active tienda' do
      create(:tienda)
      foreign_tienda = create(:tienda)
      # Cliente whose legacy tienda_id points to a DIFFERENT tienda but is
      # explicitly linked to the active tienda via the HABTM.
      shared_cliente = create(:cliente, tienda: foreign_tienda, nombre: 'Compartido SA')
      shared_cliente.tiendas << tienda

      results = described_class.new(user: usuario).relation
      expect(results).to include(shared_cliente)
    end

    it 'excludes clientes that are not linked to the active tienda' do
      foreign_tienda  = create(:tienda)
      foreign_cliente = create(:cliente, tienda: foreign_tienda, nombre: 'Ajeno SA')

      results = described_class.new(user: usuario).relation
      expect(results).not_to include(foreign_cliente)
    end
  end
end
