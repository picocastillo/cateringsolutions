require 'rails_helper'

RSpec.describe Usuarios::GruposQuery do
  let!(:grupo1) { Usuarios::Grupo.create!(nombre: 'Administradores', descripcion: 'Grupo de admins') }
  let!(:grupo2) { Usuarios::Grupo.create!(nombre: 'Operadores', descripcion: 'Grupo de operadores') }

  describe '#relation' do
    it 'returns all groups ordered by nombre' do
      query = described_class.new
      results = query.relation.to_a
      expect(results).to eq results.sort_by(&:nombre)
    end

    it 'filters by nombre' do
      query = described_class.new(nombre: 'Admin')
      expect(query.relation).to include(grupo1)
      expect(query.relation).not_to include(grupo2)
    end

    it 'filters by descripcion' do
      query = described_class.new(descripcion: 'operadores')
      expect(query.relation).to include(grupo2)
      expect(query.relation).not_to include(grupo1)
    end

    it 'filters by status active' do
      grupo2.discontinue!
      query = described_class.new(status: 'active')
      expect(query.relation).to include(grupo1)
      expect(query.relation).not_to include(grupo2)
    end

    it 'filters by status inactive' do
      grupo2.discontinue!
      query = described_class.new(status: 'inactive')
      expect(query.relation).to include(grupo2)
      expect(query.relation).not_to include(grupo1)
    end

    it 'returns all when status is all' do
      grupo2.discontinue!
      query = described_class.new(status: 'all')
      expect(query.relation).to include(grupo1, grupo2)
    end

    it 'combines nombre and status filters' do
      grupo2.discontinue!
      query = described_class.new(nombre: 'Operadores', status: 'inactive')
      expect(query.relation).to include(grupo2)
      expect(query.relation).not_to include(grupo1)
    end
  end
end
