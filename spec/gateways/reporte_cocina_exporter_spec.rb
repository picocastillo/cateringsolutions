require 'rails_helper'

RSpec.describe ReporteCocinaExporter do
  let(:tienda) { create(:tienda) }
  let!(:pedido_aceptado) { create_pedido_with_ps(estado_id: 2, cantidad: 3, precio: 100.0) }
  let!(:pedido_confirmado) { create_pedido_with_ps(estado_id: 3, cantidad: 5, precio: 100.0) }
  let(:autor) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let(:cliente) { create(:cliente, tienda: tienda, nombre: 'Cliente Test') }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:grupo) { Productos::GrupoCocina.create!(tienda: tienda, nombre: 'Entradas', codigo: 'E01') }
  let(:categoria) do
    create(:categoria, tienda: tienda, nombre: 'Verduras', grupo_cocina: grupo).tap { |c| c.update_column(:codigo, 'VER') }
  end
  let(:producto) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Lechuga') }

  def create_pedido_with_ps(estado_id:, cantidad:, precio:)
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
    let(:exporter) { described_class.new(autor: autor, tienda: tienda, params: { q: { fecha: Date.current.to_s } }) }

    it 'returns the expected column headers' do
      expect(exporter.headers).to eq(
        ['Código', 'Producto', 'Categoria', 'Grupo', 'Aceptados', 'Confirmados', 'Cantidad Total', 'Importe Total']
      )
    end
  end

  describe '#search_scope' do
    let(:exporter) { described_class.new(autor: autor, tienda: tienda, params: { q: { fecha: Date.current.to_s } }) }

    it 'returns grouped productos solicitados' do
      result = exporter.search_scope
      expect(result).not_to be_empty
      expect(result.first.producto.nombre).to eq('Lechuga')
    end

    it 'aggregates quantities across pedidos' do
      result = exporter.search_scope
      lechuga = result.find { |ps| ps.producto.nombre == 'Lechuga' }
      expect(lechuga.cantidad_sumada).to eq(8) # 3 + 5
    end

    it 'tracks accepted and confirmed counts separately' do
      result = exporter.search_scope
      lechuga = result.find { |ps| ps.producto.nombre == 'Lechuga' }
      expect(lechuga.cantidad_aceptada).to eq(3)
      expect(lechuga.cantidad_confirmada).to eq(5)
    end

    it 'sets @clientes from matching pedidos' do
      exporter.search_scope
      clientes = exporter.instance_variable_get(:@clientes)
      expect(clientes.map(&:nombre)).to include('Cliente Test')
    end

    it 'excludes cancelled and pending pedidos' do
      create_pedido_with_ps(estado_id: 5, cantidad: 10, precio: 100.0)  # cancelled
      create_pedido_with_ps(estado_id: 1, cantidad: 10, precio: 100.0)  # pending

      result = exporter.search_scope
      lechuga = result.find { |ps| ps.producto.nombre == 'Lechuga' }
      expect(lechuga.cantidad_sumada).to eq(8) # Only 3 + 5
    end
  end

  describe '#footers' do
    let(:exporter) { described_class.new(autor: autor, tienda: tienda, params: { q: { fecha: Date.current.to_s } }) }

    before { exporter.search_scope } # must call search_scope first

    it 'returns 4 footer rows' do
      expect(exporter.footers.size).to eq(4)
    end

    it 'includes total cantidad' do
      cantidad_row = exporter.footers[2]
      expect(cantidad_row[6]).to eq(8) # 3 + 5
    end
  end

  describe 'string-key resilience' do
    it 'works with string keys in params (YAML round-trip)' do
      params = { 'q' => { 'fecha' => Date.current.to_s } }
      exp = described_class.new(autor: autor, tienda: tienda, params: params)
      # query_params accesses params[:q] — string key 'q' should work after deep_symbolize_keys
      exp.run_callbacks(:save)
      result = exp.search_scope
      expect(result).not_to be_empty
    end
  end

  describe '#write_sheet' do
    let(:exporter) { described_class.new(autor: autor, tienda: tienda, params: { q: { fecha: Date.current.to_s } }) }
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

    it 'writes fecha header when fecha present' do
      fecha_row = written_rows.find { |r| r[0].to_s.start_with?('Reporte Cocina para Fecha:') }
      expect(fecha_row).not_to be_nil
    end

    it 'writes generated-at timestamp' do
      generado_row = written_rows.find { |r| r[0].to_s.start_with?('Generado el:') }
      expect(generado_row).not_to be_nil
    end

    it 'writes column headers' do
      header_row = written_rows.find { |r| r[0] == 'Código' && r[1] == 'Producto' }
      expect(header_row).not_to be_nil
    end

    it 'writes product data rows' do
      data_row = written_rows.find { |r| r[1] == 'Lechuga' }
      expect(data_row).not_to be_nil
      expect(data_row[6]).to eq(8) # cantidad_sumada
    end

    context 'without fecha in params' do
      let(:exporter) { described_class.new(autor: autor, tienda: tienda, params: { q: {} }) }

      it 'omits the fecha header' do
        fecha_row = written_rows.find { |r| r[0].to_s.start_with?('Reporte Cocina para Fecha:') }
        expect(fecha_row).to be_nil
      end
    end
  end

  context 'with venta_mostrador tienda' do
    let(:tienda_vm) { create(:tienda, venta_mostrador: true) }
    let(:autor_vm) do
      user = create(:usuario, :admin, visualizando_tienda: tienda_vm)
      user.tiendas << tienda_vm
      user
    end
    let(:cliente_vm) { create(:cliente, tienda: tienda_vm, nombre: 'Cliente VM') }
    let(:cuenta_vm) { create(:cuenta, cliente: cliente_vm) }
    let(:categoria_vm) { create(:categoria, tienda: tienda_vm, nombre: 'Cat VM') }
    let(:producto_vm) { create(:producto, tienda: tienda_vm, categoria: categoria_vm, nombre: 'Producto VM') }

    def create_vm_pedido(medio_pago_tipo:, cantidad:, precio:, estado_id: 3)
      p = Pedidos::Pedido.new(tienda: tienda_vm, cuenta: cuenta_vm, autor: autor_vm, usuario: autor_vm,
                              estado_id: 1, fecha: Date.current)
      p.asignar_cuenta_manual
      p.save!
      ps = Productos::ProductoSolicitado.new(pedido: p, producto: producto_vm, cantidad: cantidad,
                                             precio_unitario: precio, precio_con_descuento: precio)
      ps.save!(validate: false)
      p.update_columns(estado_id: estado_id, medio_pago_tipo: medio_pago_tipo, venta_mostrador: true)
      Pedidos::MedioPago.create!(pedido: p, tipo: medio_pago_tipo, importe: cantidad * precio)
      p
    end

    before do
      create_vm_pedido(medio_pago_tipo: 'efectivo', cantidad: 3, precio: 100.0)
      create_vm_pedido(medio_pago_tipo: 'debito', cantidad: 5, precio: 100.0)
    end

    describe '#search_scope' do
      let(:exporter) { described_class.new(autor: autor_vm, tienda: tienda_vm, params: { q: { fecha: Date.current.to_s, venta_mostrador: 'true' } }) }

      it 'returns flat results without medio_pago grouping' do
        result = exporter.search_scope
        expect(result).not_to be_empty
        expect(result.size).to eq(1) # single product grouped
        expect(result.first.cantidad_sumada.to_i).to eq(8) # 3 + 5
      end
    end

    describe '#write_sheet' do
      let(:exporter) { described_class.new(autor: autor_vm, tienda: tienda_vm, params: { q: { fecha: Date.current.to_s, venta_mostrador: 'true' } }) }
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

      it 'writes product data in flat list' do
        data_row = written_rows.find { |r| r[1] == 'Producto VM' }
        expect(data_row).not_to be_nil
        expect(data_row[4]).to eq(8) # cantidad_sumada
      end

      it 'writes medio de pago subtotals' do
        efectivo_row = written_rows.find { |r| r[3].to_s == 'Efectivo' }
        debito_row = written_rows.find { |r| r[3].to_s == 'Débito' }
        expect(efectivo_row).not_to be_nil
        expect(debito_row).not_to be_nil
      end

      it 'writes Total row' do
        total_row = written_rows.find { |r| r[3].to_s == 'Total' }
        expect(total_row).not_to be_nil
        expect(total_row[4]).to eq(8) # 3 + 5
      end

      it 'excludes Aceptados and Confirmados columns' do
        header_row = written_rows.find { |r| r[0] == 'Código' && r[1] == 'Producto' }
        expect(header_row).not_to include('Aceptados')
        expect(header_row).not_to include('Confirmados')
        expect(header_row[4]).to eq('Cantidad Total')
        expect(header_row[5]).to eq('Importe Total')
      end
    end
  end
end
