require 'rails_helper'

RSpec.describe Pedidos::ResumenPedidosExporter do
  let(:tienda) { create(:tienda) }
  let!(:pedido) { create_pedido_with_ps(cantidad: 5, precio: 100.0) }
  let(:exporter) do
    described_class.new(autor: autor, tienda: tienda, params: {
                          q: { fecha: Date.current.to_s }
                        })
  end
  let(:autor) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let(:cliente) { create(:cliente, tienda: tienda, nombre: 'Cliente Test') }
  let(:cuenta) { create(:cuenta, cliente: cliente) }

  let(:categoria) { create(:categoria, tienda: tienda) }
  let(:producto) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Lechuga') }

  def create_pedido_with_ps(cantidad:, precio:, estado_id: 3)
    p = Pedidos::Pedido.new(tienda: tienda, cuenta: cuenta, autor: autor, usuario: autor,
                            estado_id: 1, fecha: Date.current)
    p.asignar_cuenta_manual
    p.save!
    ps = Productos::ProductoSolicitado.new(
      pedido: p, producto: producto, cantidad: cantidad,
      precio_unitario: precio, precio_con_descuento: precio
    )
    ps.save!(validate: false)
    p.update_column(:estado_id, estado_id)
    p
  end

  describe '#headers' do
    it 'returns expected columns without date by default' do
      expect(exporter.headers).to include('DNI', 'Cliente', 'Cuenta', 'Nombre Usuario',
                                          'Cantidad Productos', 'Importe Total')
    end

    it 'has 8 columns without date' do
      expect(exporter.headers.size).to eq(8)
    end

    it 'includes Fecha column when @with_date is true' do
      exporter.instance_variable_set(:@with_date, true)
      expect(exporter.headers).to include('Fecha')
      expect(exporter.headers.size).to eq(9)
    end
  end

  describe '#search_scope' do
    it 'returns grouped productos solicitados by cuenta and usuario' do
      result = exporter.search_scope.to_a
      expect(result).not_to be_empty
    end

    it 'aggregates quantities and totals' do
      create_pedido_with_ps(cantidad: 3, precio: 100.0)

      result = exporter.search_scope.to_a
      row = result.find { |ps| ps.pedido.usuario == autor }
      expect(row.cantidad_sumada).to eq(8) # 5 + 3
      expect(row.total_sumado.to_f).to eq(800.0) # 8 * 100
    end

    it 'excludes cancelled and pending pedidos' do
      create_pedido_with_ps(cantidad: 10, precio: 100.0, estado_id: 5)

      result = exporter.search_scope.to_a
      row = result.find { |ps| ps.pedido.usuario == autor }
      expect(row.cantidad_sumada).to eq(5) # only the confirmado pedido
    end
  end

  describe '#footers' do
    it 'returns 2 footer rows' do
      expect(exporter.footers.size).to eq(2)
    end

    it 'includes total cantidad' do
      cantidad_row = exporter.footers[0]
      expect(cantidad_row[6]).to eq(5)
    end

    it 'includes total importe' do
      importe_row = exporter.footers[1]
      expect(importe_row[7].to_f).to eq(500.0)
    end
  end

  describe '#row' do
    it 'returns pedido summary data' do
      result = exporter.search_scope.to_a.first
      row = exporter.row(result)
      expect(row[3].to_s).to include('Cliente Test')
      expect(row[5]).to eq(autor.nombre)
    end
  end

  describe 'string-key resilience (YAML round-trip bug fix)' do
    it 'works with string keys in params' do
      params = { 'q' => { 'fecha' => Date.current.to_s } }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      exp.run_callbacks(:save)
      result = exp.search_scope.to_a
      expect(result).not_to be_empty
    end

    it 'works with mixed string/symbol keys in params' do
      params = { 'q' => { fecha: Date.current.to_s } }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      exp.run_callbacks(:save)
      result = exp.search_scope.to_a
      expect(result).not_to be_empty
    end
  end

  describe 'peso multiplication in totals' do
    it 'includes peso for pesable products in total importe' do
      prod_pesable = create(:producto, tienda: tienda, categoria: categoria, pesable: true, nombre: 'Carne')

      # NOTE: let!(:pedido) at top creates: qty=5, price=100 = 500
      # Create pedido with regular product (qty=5, price=100) = 500
      create_pedido_with_ps(cantidad: 5, precio: 100.0, estado_id: 3)

      # Create pedido with pesable product (qty=1, peso=2.5, price=100) = 250
      pedido_pesable = Pedidos::Pedido.new(tienda: tienda, cuenta: cuenta, autor: autor, usuario: autor,
                                           estado_id: 1, fecha: Date.current)
      pedido_pesable.asignar_cuenta_manual
      pedido_pesable.save!
      ps_pesable = Productos::ProductoSolicitado.new(
        pedido: pedido_pesable, producto: prod_pesable, cantidad: 1, peso: 2.5,
        precio_unitario: 100.0, precio_con_descuento: 100.0
      )
      ps_pesable.save!(validate: false)
      pedido_pesable.update_column(:estado_id, 3)

      # Expected: 500 (let!) + 500 (regular) + 250 (pesable) = 1250
      footers = exporter.footers
      total_importe = footers[1][7].to_f
      expect(total_importe).to eq(1250.0)
    end
  end
end
