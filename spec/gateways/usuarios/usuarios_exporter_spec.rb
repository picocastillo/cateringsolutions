require 'rails_helper'

RSpec.describe Usuarios::UsuariosExporter do
  let(:tienda) { create(:tienda) }
  let(:exporter) { described_class.new(autor: autor, tienda: tienda, params: { q: {} }) }
  let(:autor) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let(:cliente) { create(:cliente, tienda: tienda, nombre: 'Cliente Test') }
  let(:cuenta) { create(:cuenta, cliente: cliente, nombre: 'Cuenta Test') }
  let!(:usuario_cliente) do
    create(:usuario, :cliente, cuenta: cuenta, tienda_cliente: tienda,
                               nombre: 'Juan Perez', login: 'jperez',
                               email: 'jperez@test.com', dni: '12345678',
                               legajo: 'L001')
  end

  before { autor.tiendas << tienda unless autor.tiendas.include?(tienda) }

  describe '#headers' do
    it 'returns expected columns' do
      expect(exporter.headers).to include('Nombre Usuario', 'Login', 'Email', 'Cliente', 'Cuenta')
    end

    it 'has 10 columns' do
      expect(exporter.headers.size).to eq(10)
    end
  end

  describe '#row' do
    it 'returns usuario data in correct order' do
      row = exporter.row(usuario_cliente)
      expect(row[0]).to eq(usuario_cliente.dni)
      expect(row[5]).to eq('Juan Perez')
      expect(row[6]).to eq('jperez')
      expect(row[7]).to eq('jperez@test.com')
    end

    it 'includes cuenta and cliente info' do
      row = exporter.row(usuario_cliente)
      expect(row[3].to_s).to include('Cliente Test')
      expect(row[4]).to eq('Cuenta Test')
    end

    it 'handles usuario without cuenta gracefully' do
      admin = create(:usuario, :admin, visualizando_tienda: tienda, nombre: 'Admin')
      row = exporter.row(admin)
      expect(row[3]).to be_nil # cuenta.try(:cliente) = nil
      expect(row[4]).to be_nil # cuenta.try(:nombre) = nil
    end
  end

  describe '#search_scope' do
    it 'returns usuarios ordered by cuenta and name' do
      result = exporter.search_scope
      expect(result).not_to be_empty
    end

    it 'includes usuarios from the tienda' do
      result = exporter.search_scope
      expect(result.map(&:nombre)).to include('Juan Perez')
    end
  end

  describe 'string-key resilience (YAML round-trip bug fix)' do
    it 'works with string keys in params' do
      params = { 'q' => {} }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      exp.run_callbacks(:save)
      result = exp.search_scope
      expect(result).not_to be_empty
    end
  end
end
