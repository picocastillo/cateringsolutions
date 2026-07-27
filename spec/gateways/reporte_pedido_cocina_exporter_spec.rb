require 'rails_helper'

RSpec.describe ReportePedidoCocinaExporter do
  let(:tienda) { create(:tienda) }
  let(:pedido_a) { create_pedido_with_cuenta(cuenta_a) }
  let(:pedido_b) { create_pedido_with_cuenta(cuenta_b) }
  let(:pedido_cocina) do
    # Create PedidoCocina while pedidos are pendiente (passes validation)
    pc = Pedidos::PedidoCocina.new(tienda: tienda, autor: autor, pedidos: [pedido_a, pedido_b])
    pc.save!

    # Add productos_solicitados
    create_ps(pedido_a, producto_lechuga, 3, 100.0)
    create_ps(pedido_a, producto_bife, 2, 250.0)
    create_ps(pedido_a, producto_brownie, 1, 80.0)
    create_ps(pedido_b, producto_lechuga, 2, 100.0)
    create_ps(pedido_b, producto_brocoli, 4, 90.0)
    create_ps(pedido_b, producto_agua, 5, 50.0)

    # Set estado to confirmado (bypassing validation)
    pedido_a.update_column(:estado_id, 3)
    pedido_b.update_column(:estado_id, 3)
    pc
  end
  # Force creation of all test data
  let!(:setup_data) { pedido_cocina }
  # Simulate controller params: export_in_background passes filtered_params
  # Controller does: request.parameters["pedido_cocina_id"] = @pedido_cocina.id
  let(:controller_params) do
    { pedido_cocina_id: pedido_cocina.id, q: { fecha: Date.current.to_s } }
  end
  let(:exporter) do
    described_class.new(autor: autor, tienda: tienda, params: controller_params)
  end
  let(:autor) { create(:usuario, :admin, visualizando_tienda: tienda) }

  # Two clientes to test the "Clientes:" header line
  let(:cliente_a) { create(:cliente, tienda: tienda, nombre: 'Alfa Foods') }
  let(:cliente_b) { create(:cliente, tienda: tienda, nombre: 'Beta Catering') }
  let(:cuenta_a) { create(:cuenta, cliente: cliente_a) }
  let(:cuenta_b) { create(:cuenta, cliente: cliente_b) }

  # Groups and categories to test sort order
  let(:grupo_z) { Productos::GrupoCocina.create!(tienda: tienda, nombre: 'Postres', codigo: 'Z01') }
  let(:grupo_a) { Productos::GrupoCocina.create!(tienda: tienda, nombre: 'Entradas', codigo: 'A01') }

  let(:categoria_verduras) do
    create(:categoria, tienda: tienda, nombre: 'Verduras', grupo_cocina: grupo_a).tap { |c| c.update_column(:codigo, 'CAT-B') }
  end
  let(:categoria_carnes) do
    create(:categoria, tienda: tienda, nombre: 'Carnes', grupo_cocina: grupo_a).tap { |c| c.update_column(:codigo, 'CAT-A') }
  end
  let(:categoria_dulces) do
    create(:categoria, tienda: tienda, nombre: 'Dulces', grupo_cocina: grupo_z).tap { |c| c.update_column(:codigo, 'CAT-D') }
  end
  let(:categoria_sin_grupo) do
    # No grupo_cocina → grupo returns "Sin Grupo"
    create(:categoria, tienda: tienda, nombre: 'Otros', grupo_cocina: nil).tap { |c| c.update_column(:codigo, 'CAT-Z') }
  end

  # Products — names chosen to also test alphabetical tie-breaking within same category
  let(:producto_lechuga) { create(:producto, tienda: tienda, categoria: categoria_verduras, nombre: 'Lechuga') }
  let(:producto_brocoli) { create(:producto, tienda: tienda, categoria: categoria_verduras, nombre: 'Brócoli') }
  let(:producto_bife) { create(:producto, tienda: tienda, categoria: categoria_carnes, nombre: 'Bife de Chorizo') }
  let(:producto_brownie) { create(:producto, tienda: tienda, categoria: categoria_dulces, nombre: 'Brownie') }
  let(:producto_agua) { create(:producto, tienda: tienda, categoria: categoria_sin_grupo, nombre: 'Agua Mineral') }

  # Helper to create pedido with cuenta preserved (asignar_cuenta_manual prevents callback override)
  def create_pedido_with_cuenta(cuenta)
    p = Pedidos::Pedido.new(tienda: tienda, cuenta: cuenta, autor: autor, usuario: autor,
                            estado_id: 1, fecha: Date.current)
    p.asignar_cuenta_manual
    p.save!
    p
  end

  # Helper to create ProductoSolicitado without triggering asignar_precio callback
  def create_ps(pedido, producto, cantidad, precio)
    ps = Productos::ProductoSolicitado.new(
      pedido: pedido, producto: producto, cantidad: cantidad,
      precio_unitario: precio, precio_con_descuento: precio
    )
    ps.save!(validate: false)
    ps
  end

  describe '#pedido_cocina_id' do
    it 'extracts pedido_cocina_id from top-level params' do
      expect(exporter.send(:pedido_cocina_id)).to eq(pedido_cocina.id)
    end

    it 'falls back to params[:id] when pedido_cocina_id is absent' do
      exporter_alt = described_class.new(
        autor: autor, tienda: tienda,
        params: { id: pedido_cocina.id, q: {} }
      )
      expect(exporter_alt.send(:pedido_cocina_id)).to eq(pedido_cocina.id)
    end

    it 'falls back to params[:q][:pedido_cocina_id] as last resort' do
      exporter_alt = described_class.new(
        autor: autor, tienda: tienda,
        params: { q: { pedido_cocina_id: pedido_cocina.id } }
      )
      expect(exporter_alt.send(:pedido_cocina_id)).to eq(pedido_cocina.id)
    end
  end

  describe '#headers' do
    it 'returns Producto and Cantidad columns' do
      expect(exporter.headers).to eq(['Producto', 'Cantidad'])
    end
  end

  describe '#search_scope' do
    let(:result) { exporter.search_scope }

    it 'returns productos solicitados grouped by producto' do
      product_names = result.map { |ps| ps.producto.nombre }
      expect(product_names).to include('Lechuga', 'Brócoli', 'Bife de Chorizo', 'Brownie', 'Agua Mineral')
    end

    it 'aggregates cantidad_sumada across pedidos for same product' do
      lechuga_row = result.find { |ps| ps.producto.nombre == 'Lechuga' }
      # pedido_a: 3, pedido_b: 2 → total 5
      expect(lechuga_row.cantidad_sumada).to eq(5)
    end

    it 'sets @clientes with ordered client names from the pedidos' do
      result # trigger search_scope
      clientes = exporter.instance_variable_get(:@clientes)
      expect(clientes.map(&:nombre)).to eq(['Alfa Foods', 'Beta Catering'])
    end

    describe 'sort order: grupo → categoria codigo → producto nombre' do
      it 'sorts by grupo_cocina name first' do
        groups = result.map { |ps| ps.producto.categoria.grupo.to_s }
        # "Entradas" (grupo_a) < "Postres" (grupo_z) < "Sin Grupo" (nil)
        expected_order = groups.sort
        expect(groups).to eq(expected_order)
      end

      it 'sorts by categoria codigo within same grupo' do
        # Within grupo "Entradas": CAT-A (Carnes) before CAT-B (Verduras)
        entradas_items = result.select { |ps| ps.producto.categoria.grupo_cocina == grupo_a }
        codigos = entradas_items.map { |ps| ps.producto.categoria.codigo }
        expect(codigos).to eq(codigos.sort)
      end

      it 'sorts by producto nombre within same categoria' do
        # Within Verduras (CAT-B): Brócoli before Lechuga
        verduras_items = result.select { |ps| ps.producto.categoria == categoria_verduras }
        nombres = verduras_items.map { |ps| ps.producto.nombre }
        expect(nombres).to eq(nombres.sort)
      end

      it 'produces the exact expected full order' do
        expected_names = [
          'Bife de Chorizo',  # Entradas / CAT-A (Carnes)
          'Brócoli',          # Entradas / CAT-B (Verduras)
          'Lechuga',          # Entradas / CAT-B (Verduras)
          'Brownie',          # Postres  / CAT-D (Dulces)
          'Agua Mineral'      # Sin Grupo / CAT-Z (Otros)
        ]
        actual_names = result.map { |ps| ps.producto.nombre }
        expect(actual_names).to eq(expected_names)
      end
    end

    it 'only includes productos from pedidos belonging to the pedido_cocina' do
      # Create an unrelated pedido NOT in this pedido_cocina
      other_pedido = create_pedido_with_cuenta(cuenta_a)
      other_producto = create(:producto, tienda: tienda, categoria: categoria_carnes, nombre: 'Chorizo Extra')
      create_ps(other_pedido, other_producto, 10, 200.0)
      other_pedido.update_column(:estado_id, 3)

      product_names = result.map { |ps| ps.producto.nombre }
      expect(product_names).not_to include('Chorizo Extra')
    end

    it 'excludes cancelled and pending pedidos' do
      cancelled = create_pedido_with_cuenta(cuenta_a)
      create_ps(cancelled, create(:producto, tienda: tienda, categoria: categoria_carnes, nombre: 'Cancelado'), 3, 100.0)
      cancelled.update_column(:estado_id, 5)
      cancelled.update_column(:pedido_cocina_id, pedido_cocina.id)

      pending = create_pedido_with_cuenta(cuenta_a)
      create_ps(pending, create(:producto, tienda: tienda, categoria: categoria_carnes, nombre: 'Pendiente'), 2, 100.0)
      pending.update_column(:pedido_cocina_id, pedido_cocina.id)

      product_names = result.map { |ps| ps.producto.nombre }
      expect(product_names).not_to include('Cancelado', 'Pendiente')
    end
  end

  describe '#footers' do
    it 'returns TOTAL row with sum of all cantidades' do
      # Total: lechuga(3+2) + brocoli(4) + bife(2) + brownie(1) + agua(5) = 17
      expect(exporter.footers).to eq([['TOTAL', 17]])
    end
  end

  describe '#write_sheet' do
    let(:written_rows) { [] }

    before do
      allow(exporter).to receive(:write_row).and_wrap_original do |method, sheet, data, format = nil|
        written_rows << data
        method.call(sheet, data, format)
      end
      wb = WriteXLSX.new(StringIO.new)
      sheet = wb.add_worksheet
      exporter.instance_variable_set(:@workbook, wb)
      exporter.send(:setup_formats)
      exporter.instance_variable_set(:@current_row, 0)
      exporter.write_sheet(sheet, [])
      wb.close
    end

    it 'writes the pedido cocina codigo header' do
      expect(written_rows[0][0]).to match(/PEDIDO COCINA N: #{pedido_cocina.codigo}/)
    end

    it 'writes the fecha header when fecha present in params' do
      fecha_row = written_rows.find { |r| r[0].to_s.start_with?('Fecha:') }
      expect(fecha_row[0]).to include(Date.current.to_s)
    end

    it 'writes the generated-at timestamp header' do
      generado_row = written_rows.find { |r| r[0].to_s.start_with?('Generado el:') }
      expect(generado_row).not_to be_nil
    end

    it 'writes the clientes header with sorted names' do
      clientes_row = written_rows.find { |r| r[0].to_s.start_with?('Clientes:') }
      expect(clientes_row[0]).to include('Alfa Foods')
      expect(clientes_row[0]).to include('Beta Catering')
    end

    it 'writes the total productos count header' do
      total_row = written_rows.find { |r| r[0].to_s.start_with?('Cantidad Total Productos:') }
      expect(total_row[0]).to include('17')
    end

    it 'writes column headers' do
      header_row = written_rows.find { |r| r[0] == 'Producto' && r[1] == 'Cantidad' }
      expect(header_row).not_to be_nil
    end

    it 'writes product data rows in correct sort order' do
      # Find the index of the column headers row
      header_idx = written_rows.index { |r| r[0] == 'Producto' && r[1] == 'Cantidad' }
      data_rows = written_rows[(header_idx + 1)..-2] # Exclude footer

      product_names = data_rows.pluck(0)
      expect(product_names).to eq([
                                    'Bife de Chorizo',
                                    'Brócoli',
                                    'Lechuga',
                                    'Brownie',
                                    'Agua Mineral'
                                  ])
    end

    it 'writes correct aggregated quantities per product' do
      header_idx = written_rows.index { |r| r[0] == 'Producto' && r[1] == 'Cantidad' }
      data_rows = written_rows[(header_idx + 1)..-2]

      quantities = data_rows.map { |r| [r[0], r[1]] }
      expect(quantities).to include(['Bife de Chorizo', 2])
      expect(quantities).to include(['Brócoli', 4])
      expect(quantities).to include(['Lechuga', 5])
      expect(quantities).to include(['Brownie', 1])
      expect(quantities).to include(['Agua Mineral', 5])
    end

    it 'writes TOTAL footer as last row' do
      last_row = written_rows.last
      expect(last_row[0]).to eq('TOTAL')
      expect(last_row[1]).to eq(17)
    end

    context 'when fecha is not present in params' do
      let(:controller_params) { { pedido_cocina_id: pedido_cocina.id, q: {} } }

      it 'omits the fecha header row' do
        fecha_row = written_rows.find { |r| r[0].to_s.start_with?('Fecha:') }
        expect(fecha_row).to be_nil
      end
    end

    context 'when there are no clientes (empty results)' do
      let(:pedido_cocina_empty) do
        p = create_pedido_with_cuenta(cuenta_a)
        pc = Pedidos::PedidoCocina.new(tienda: tienda, autor: autor, pedidos: [p])
        pc.save!
        create_ps(p, producto_agua, 1, 50.0)
        p.update_column(:estado_id, 5) # cancelled → excluded by pedidos_activos
        pc
      end
      let(:controller_params) { { pedido_cocina_id: pedido_cocina_empty.id, q: {} } }

      it 'omits the clientes header row' do
        clientes_row = written_rows.find { |r| r[0].to_s.start_with?('Clientes:') }
        expect(clientes_row).to be_nil
      end
    end
  end

  describe 'integration: controller param patterns' do
    it 'works with the show action pattern (pedido_cocina_id in top-level params)' do
      # Controller does: request.parameters["pedido_cocina_id"] = @pedido_cocina.id
      params = { pedido_cocina_id: pedido_cocina.id, q: { fecha: Date.current.to_s } }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      result = exp.search_scope
      expect(result).not_to be_empty
    end

    it 'works with id param (route-based)' do
      params = { id: pedido_cocina.id, q: {} }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      result = exp.search_scope
      expect(result).not_to be_empty
    end

    it 'works with nested q param' do
      params = { q: { pedido_cocina_id: pedido_cocina.id } }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      result = exp.search_scope
      expect(result).not_to be_empty
    end
  end

  describe 'string-key resilience (YAML round-trip bug fix)' do
    it 'works when params have string keys from YAML deserialization' do
      params = { 'id' => pedido_cocina.id, 'q' => { 'fecha' => Date.current.to_s } }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      expect(exp.send(:pedido_cocina_id)).to eq(pedido_cocina.id)
      expect(exp.search_scope).not_to be_empty
    end

    it 'works when params have mixed string and symbol keys' do
      params = { 'id' => pedido_cocina.id, q: { fecha: Date.current.to_s } }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      expect(exp.send(:pedido_cocina_id)).to eq(pedido_cocina.id)
    end

    it 'works with string pedido_cocina_id key' do
      params = { 'pedido_cocina_id' => pedido_cocina.id }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      expect(exp.send(:pedido_cocina_id)).to eq(pedido_cocina.id)
    end

    it 'works with string nested q key' do
      params = { 'q' => { 'pedido_cocina_id' => pedido_cocina.id } }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      expect(exp.send(:pedido_cocina_id)).to eq(pedido_cocina.id)
    end

    it 'raises RecordNotFound when id is truly missing' do
      params = { q: {} }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      expect { exp.send(:pedido_cocina) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
