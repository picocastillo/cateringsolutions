require 'rails_helper'

RSpec.describe ReporteDespachoExporter do
  let(:tienda) { create(:tienda) }
  let!(:pedido) { create_confirmed_pedido(cantidad: 5, precio: 100.0) }
  let(:exporter) do
    described_class.new(autor: autor, tienda: tienda, params: {
                          q: { fecha_desde: Date.current.to_s, fecha_hasta: Date.current.to_s }
                        })
  end
  let(:autor) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let(:cliente) { create(:cliente, tienda: tienda, nombre: 'Cliente Test') }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:categoria) do
    create(:categoria, tienda: tienda).tap { |c| c.update_column(:codigo, 'CAT01') }
  end
  let(:producto) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Lechuga') }

  def create_confirmed_pedido(cantidad:, precio:)
    p = Pedidos::Pedido.new(tienda: tienda, cuenta: cuenta, autor: autor, usuario: autor,
                            estado_id: 1, fecha: Date.current)
    p.asignar_cuenta_manual
    p.save!
    ps = Productos::ProductoSolicitado.new(
      pedido: p, producto: producto, cantidad: cantidad,
      precio_unitario: precio, precio_con_descuento: precio
    )
    ps.save!(validate: false)
    p.update_column(:estado_id, 3)
    p
  end

  describe '#headers' do
    it 'includes base columns' do
      # search_scope must be called first to set @query
      exporter.search_scope
      expect(exporter.headers).to include('Enviar a', 'Producto', 'Cantidad')
    end
  end

  describe '#search_scope' do
    it 'returns despachos for confirmed pedidos' do
      result = exporter.search_scope
      expect(result).not_to be_empty
    end

    it 'only includes confirmed pedidos (estado 3)' do
      # Create a non-confirmed pedido that should be excluded
      p = Pedidos::Pedido.new(tienda: tienda, cuenta: cuenta, autor: autor, usuario: autor,
                              estado_id: 1, fecha: Date.current)
      p.asignar_cuenta_manual
      p.save!
      ps = Productos::ProductoSolicitado.new(
        pedido: p, producto: producto, cantidad: 10,
        precio_unitario: 100.0, precio_con_descuento: 100.0
      )
      ps.save!(validate: false)
      p.update_column(:estado_id, 2) # aceptado, not confirmado

      result = exporter.search_scope
      pedido_ids = result.map { |d| d.pedido.id }.uniq
      expect(pedido_ids).not_to include(p.id)
    end
  end

  describe 'string-key resilience (YAML round-trip bug fix)' do
    it 'works with string keys in params' do
      params = { 'q' => { 'fecha_desde' => Date.current.to_s, 'fecha_hasta' => Date.current.to_s } }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      exp.run_callbacks(:save)
      result = exp.search_scope
      expect(result).not_to be_empty
    end
  end
end
