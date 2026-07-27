require 'rails_helper'

RSpec.describe ApplicationQuery do
  let(:tienda) { create(:tienda) }
  let(:usuario) { create(:usuario, :admin, visualizando_tienda: tienda) }

  describe '#run' do
    it 'returns relation when valid and autorun' do
      query = Productos::ProductosQuery.new(user: usuario, autorun: true)
      expect(query.run).to be_a(ActiveRecord::Relation)
    end

    it 'returns none when invalid' do
      query = Clientes::ClientesQuery.new(autorun: true)
      expect(query.run).to be_empty
    end

    it 'returns none when autorun is false' do
      query = Productos::ProductosQuery.new(user: usuario, autorun: false)
      expect(query.run).to be_empty
    end
  end

  describe '#to_params' do
    it 'returns a hash excluding internal variables' do
      query = Productos::ProductosQuery.new(user: usuario, nombre: 'Test')
      params = query.to_params
      expect(params).to be_a(Hash)
      expect(params.keys).not_to include('autorun', 'errors', 'validation_context')
    end
  end

  describe 'delegation' do
    it 'delegates to_a to run' do
      query = Productos::ProductosQuery.new(user: usuario)
      expect(query.to_a).to be_a(Array)
    end

    it 'delegates empty? to run' do
      query = Productos::ProductosQuery.new(user: usuario)
      expect(query).to respond_to(:empty?)
    end

    it 'delegates any? to run' do
      query = Productos::ProductosQuery.new(user: usuario)
      expect(query).to respond_to(:any?)
    end
  end
end
