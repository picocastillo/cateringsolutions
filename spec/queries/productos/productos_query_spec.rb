require 'rails_helper'

RSpec.describe Productos::ProductosQuery do
  let(:tienda) { create(:tienda) }
  let(:usuario) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let(:categoria) { create(:categoria, tienda: tienda) }
  let!(:producto1) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Milanesa de Pollo', codigo: 'MIL001') }
  let!(:producto2) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Ensalada Caesar', codigo: 'ENS002') }

  describe '#relation' do
    it 'returns products for user tienda' do
      other_tienda = create(:tienda)
      create(:producto, tienda: other_tienda, nombre: 'Other Product')

      query = described_class.new(user: usuario)
      expect(query.relation).to include(producto1, producto2)
      expect(query.relation.to_a.length).to eq 2
    end

    it 'filters by nombre' do
      query = described_class.new(user: usuario, nombre: 'Milanesa')
      expect(query.relation).to include(producto1)
      expect(query.relation).not_to include(producto2)
    end

    it 'filters by codigo' do
      query = described_class.new(user: usuario, codigo: 'ENS002')
      expect(query.relation).to include(producto2)
      expect(query.relation).not_to include(producto1)
    end

    it 'filters by categoria_ids' do
      other_cat = create(:categoria, tienda: tienda)
      producto3 = create(:producto, tienda: tienda, categoria: other_cat, nombre: 'Otro')

      query = described_class.new(user: usuario, categoria_ids: [other_cat.id])
      expect(query.relation).to include(producto3)
      expect(query.relation).not_to include(producto1)
    end

    it 'filters by busqueda matching nombre' do
      query = described_class.new(user: usuario, busqueda: 'Pollo')
      expect(query.relation).to include(producto1)
      expect(query.relation).not_to include(producto2)
    end

    it 'filters by busqueda matching codigo' do
      query = described_class.new(user: usuario, busqueda: 'MIL001')
      expect(query.relation).to include(producto1)
      expect(query.relation).not_to include(producto2)
    end

    it 'filters by descripcion' do
      producto1.update!(descripcion: 'Rebozada con pan rallado')
      query = described_class.new(user: usuario, descripcion: 'Rebozada')
      expect(query.relation).to include(producto1)
      expect(query.relation).not_to include(producto2)
    end

    it 'filters by codigo_externo' do
      producto1.update!(codigos_externos: 'EXT001, EXT002')
      query = described_class.new(user: usuario, codigo_externo: 'EXT001')
      expect(query.relation).to include(producto1)
      expect(query.relation).not_to include(producto2)
    end

    it 'orders by nombre' do
      results = described_class.new(user: usuario).relation
      expect(results.first.nombre).to be <= results.last.nombre
    end
  end
end
