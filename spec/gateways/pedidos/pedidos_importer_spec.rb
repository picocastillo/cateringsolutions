require 'rails_helper'
require 'write_xlsx'

RSpec.describe Pedidos::PedidosImporter, type: :gateway do
  let(:tienda) { create(:tienda, nombre: 'Tienda Import Test', dominio: 'www.example.com') }
  let(:cliente) { create(:cliente, tienda: tienda) }
  let(:cuenta_a) { create(:cuenta, cliente: cliente, nombre: 'Sucursal A') }
  let(:cuenta_b) { create(:cuenta, cliente: cliente, nombre: 'Sucursal B') }
  let(:categoria) { create(:categoria, tienda: tienda, nombre: 'Menú') }
  let(:admin_user) do
    u = create(:usuario, :admin, visualizando_tienda: tienda)
    u.tiendas << tienda unless u.tiendas.include?(tienda)
    u
  end

  let(:fecha) { Date.current + 1.day }

  let!(:producto_a) do
    create(:producto, tienda: tienda, categoria: categoria, nombre: 'Milanesa', codigo: 'MIL001')
  end
  let!(:producto_b) do
    create(:producto, tienda: tienda, categoria: categoria, nombre: 'Ensalada', codigo: 'ENS001')
  end

  let!(:precio_a) do
    create(:precio, :for_cliente, producto: producto_a, importe: 500.0,
                                  fecha_desde: Date.current - 1.month, fecha_hasta: Date.current + 1.year,
                                  cliente: cliente)
  end
  let!(:precio_b) do
    create(:precio, :for_cliente, producto: producto_b, importe: 300.0,
                                  fecha_desde: Date.current - 1.month, fecha_hasta: Date.current + 1.year,
                                  cliente: cliente)
  end

  before do
    allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante)
    allow_any_instance_of(Pedidos::Pedido).to receive(:updatear_avisos_cocina)
    allow_any_instance_of(Pedidos::Pedido).to receive(:confirmar!) do |pedido|
      pedido.no_validar_fecha = true
      pedido.estado_id = 3
      pedido.save!
    end
  end

  # ---------------------------------------------------------------------------
  # Helper: build Excel file
  # ---------------------------------------------------------------------------
  def build_excel_file(rows)
    file = Tempfile.new(['pedidos_import', '.xlsx'])
    workbook = WriteXLSX.new(file.path)
    sheet = workbook.add_worksheet
    rows.each_with_index do |row, idx|
      row.each_with_index do |cell, col|
        sheet.write(idx, col, cell)
      end
    end
    workbook.close
    file.rewind
    file
  end

  def standard_headers
    ['Código del menú', 'Nombre del menú', 'Nombre de empleado', 'Lugar de entrega', 'Cantidad']
  end

  def build_standard_excel(data_rows, date: fecha)
    rows = [
      [date.to_fs(:db), 'Fecha de pedidos'],
      standard_headers
    ] + data_rows
    build_excel_file(rows)
  end

  def create_importer(file_path, cliente_id: cliente.id, fecha_param: fecha)
    importer = described_class.new(
      autor: admin_user,
      tienda: tienda,
      importar: true,
      params: { 'cliente_id' => cliente_id, 'fecha' => fecha_param.to_s },
      adjunto: File.open(file_path)
    )
    importer.save!
    importer
  end

  # ===========================================================================
  # Inheritance & structure
  # ===========================================================================
  describe 'class hierarchy' do
    it 'inherits from ExcelImporter' do
      expect(described_class.superclass).to eq(ExcelImporter)
    end

    it 'inherits from Infraestructura::Procesos::Proceso' do
      expect(described_class.ancestors).to include(Infraestructura::Procesos::Proceso)
    end
  end

  # ===========================================================================
  # Date validation in row 1
  # ===========================================================================
  describe 'date validation' do
    it 'raises error when first row date does not match' do
      wrong_date = fecha + 5.days
      file = build_standard_excel(
        [['MIL001', 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]],
        date: wrong_date
      )
      importer = create_importer(file.path)
      expect { importer.run(file.path) }.to raise_error(ErrorAplicacion, /no coincide con la fecha/)
    end

    it 'transitions progreso to Error when perform catches the exception' do
      wrong_date = fecha + 5.days
      file = build_standard_excel(
        [['MIL001', 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]],
        date: wrong_date
      )
      importer = create_importer(file.path)
      expect { importer.perform }.to raise_error(ErrorAplicacion, /no coincide con la fecha/)
      importer.progreso.reload
      expect(importer.progreso.estado).to eq('Error')
      expect(importer.progreso.errores).to include(a_string_matching(/no coincide con la fecha/))
      expect(importer.progreso).to be_termino
    end

    it 'succeeds when first row date matches' do
      file = build_standard_excel([['MIL001', 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]])
      importer = create_importer(file.path)
      expect { importer.run(file.path) }.not_to raise_error
    end
  end

  # ===========================================================================
  # Cuenta validation
  # ===========================================================================
  describe 'cuenta validation' do
    it 'records error for non-existent cuenta name' do
      file = build_standard_excel([['MIL001', 'Milanesa', 'Juan Perez', 'Inexistente', 1]])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(importer.progreso.error?).to be true
      expect(importer.progreso.errores.first).to include('No existe la cuenta')
    end

    it 'accepts valid cuenta name' do
      file = build_standard_excel([['MIL001', 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.where(fecha: fecha).count).to eq(1)
    end
  end

  # ===========================================================================
  # Duplicate pedido detection
  # ===========================================================================
  describe 'duplicate pedido detection' do
    it 'records error when non-cancelled pedidos exist for same fecha/cuenta' do
      existing = Pedidos::Pedido.new(
        tienda: tienda, cuenta: cuenta_a, fecha: fecha,
        estado_id: 2, pedido_para_empresa: true, autor: admin_user,
        usuario_id: nil, para: 'Existing', no_validar_fecha: true
      )
      existing.productos_solicitados.build(producto: producto_a, cantidad: 1, precio_unitario: 500.0)
      existing.save!

      file = build_standard_excel([['MIL001', 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(importer.progreso.error?).to be true
      expect(importer.progreso.errores.first).to include('Ya se registran pedidos cargados')
    end

    it 'allows import when existing pedidos are all cancelled' do
      existing = Pedidos::Pedido.new(
        tienda: tienda, cuenta: cuenta_a, fecha: fecha,
        estado_id: 2, pedido_para_empresa: true, autor: admin_user,
        usuario_id: nil, para: 'Cancelled', no_validar_fecha: true
      )
      existing.productos_solicitados.build(producto: producto_a, cantidad: 1, precio_unitario: 500.0)
      existing.save!
      existing.update_column(:estado_id, 5)

      file = build_standard_excel([['MIL001', 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.where(fecha: fecha).where.not(estado_id: 5).count).to eq(1)
    end
  end

  # ===========================================================================
  # Product lookup
  # ===========================================================================
  describe 'product lookup' do
    it 'finds product by codigo' do
      file = build_standard_excel([[producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]])
      importer = create_importer(file.path)
      importer.run(file.path)
      pedido = Pedidos::Pedido.last
      expect(pedido.productos_solicitados.first.producto).to eq(producto_a)
    end

    it 'finds product by codigos_externos' do
      producto_a.update_column(:codigos_externos, 'EXT100, EXT200')
      file = build_standard_excel([['EXT100', 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]])
      importer = create_importer(file.path)
      importer.run(file.path)
      pedido = Pedidos::Pedido.last
      expect(pedido.productos_solicitados.first.producto).to eq(producto_a)
    end

    it 'scopes product lookup to tienda' do
      other_tienda = create(:tienda, nombre: 'Otra Tienda')
      create(:producto, tienda: other_tienda, categoria: categoria, nombre: 'Milanesa', codigo: 'SHARED001')

      file = build_standard_excel([['SHARED001', 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(importer.progreso.error?).to be true
      expect(importer.progreso.errores.first).to include('No existe ningún producto activo')
    end

    it 'records error for non-existent product code' do
      file = build_standard_excel([['INVALID', 'No existe', 'Juan Perez', cuenta_a.nombre, 1]])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(importer.progreso.error?).to be true
      expect(importer.progreso.errores.first).to include('No existe ningún producto activo')
    end
  end

  # ===========================================================================
  # Price validation
  # ===========================================================================
  describe 'price validation' do
    it 'records error when no active price exists' do
      create(:producto, tienda: tienda, categoria: categoria,
                        nombre: 'Sin Precio', codigo: 'SP001')
      file = build_standard_excel([['SP001', 'Sin Precio', 'Juan Perez', cuenta_a.nombre, 1]])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(importer.progreso.error?).to be true
      expect(importer.progreso.errores.first).to include('No existen precios activos')
    end

    it 'uses the correct price' do
      file = build_standard_excel([[producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.last.productos_solicitados.first.precio_unitario).to eq(500.0)
    end
  end

  # ===========================================================================
  # Employee grouping
  # ===========================================================================
  describe 'employee name grouping' do
    it 'groups rows for the same employee into one pedido' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'juan perez', cuenta_a.nombre, 1],
                                    [producto_b.codigo, 'Ensalada', 'juan perez', cuenta_a.nombre, 1]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)
      pedidos = Pedidos::Pedido.where(fecha: fecha, para: 'Juan Perez')
      expect(pedidos.count).to eq(1)
      expect(pedidos.first.productos_solicitados.size).to eq(2)
    end

    it 'creates separate pedidos for different employees' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'juan perez', cuenta_a.nombre, 1],
                                    [producto_b.codigo, 'Ensalada', 'maria lopez', cuenta_a.nombre, 1]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.where(fecha: fecha).count).to eq(2)
    end

    it 'capitalizes each word in employee name' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'JUAN CARLOS PEREZ', cuenta_a.nombre, 1]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.last.para).to eq('Juan Carlos Perez')
    end

    it 'strips commas from employee names' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'perez, juan', cuenta_a.nombre, 1]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.last.para).to eq('Perez Juan')
    end
  end

  # ===========================================================================
  # Quantity handling
  # ===========================================================================
  describe 'quantity handling' do
    it 'defaults to 1 when Cantidad is blank' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, nil]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.last.productos_solicitados.first.cantidad).to eq(1)
    end

    it 'uses specified quantity' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, 3]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.last.productos_solicitados.first.cantidad).to eq(3)
    end

    it 'defaults to 1 when quantity is zero' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, 0]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.last.productos_solicitados.first.cantidad).to eq(1)
    end

    it 'accumulates quantity for same employee + same product' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, 2],
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)
      ps = Pedidos::Pedido.last.productos_solicitados.find_by(producto: producto_a)
      expect(ps.cantidad).to eq(3)
    end
  end

  # ===========================================================================
  # Pedido attributes
  # ===========================================================================
  describe 'created pedido attributes' do
    before do
      file = build_standard_excel([[producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1]])
      importer = create_importer(file.path)
      importer.run(file.path)
    end

    it 'sets pedido_para_empresa to true' do
      expect(Pedidos::Pedido.last.pedido_para_empresa).to be true
    end

    it 'sets autor to the proceso autor' do
      expect(Pedidos::Pedido.last.autor).to eq(admin_user)
    end

    it 'sets tienda' do
      expect(Pedidos::Pedido.last.tienda).to eq(tienda)
    end

    it 'sets usuario_id to nil' do
      expect(Pedidos::Pedido.last.usuario_id).to be_nil
    end

    it 'sets cuenta from Lugar de entrega' do
      expect(Pedidos::Pedido.last.cuenta).to eq(cuenta_a)
    end

    it 'calls confirmar! on each pedido' do
      # Already confirmed by the stub — estado should be 3
      expect(Pedidos::Pedido.last.estado_id).to eq(3)
    end
  end

  # ===========================================================================
  # Multiple cuentas
  # ===========================================================================
  describe 'multiple cuentas in same file' do
    it 'creates pedidos with different cuentas' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1],
                                    [producto_b.codigo, 'Ensalada', 'Maria Lopez', cuenta_b.nombre, 1]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.find_by(para: 'Juan Perez').cuenta).to eq(cuenta_a)
      expect(Pedidos::Pedido.find_by(para: 'Maria Lopez').cuenta).to eq(cuenta_b)
    end
  end

  # ===========================================================================
  # Empty rows
  # ===========================================================================
  describe 'empty rows handling' do
    it 'skips empty rows' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1],
                                    [nil, nil, nil, nil, nil],
                                    [producto_b.codigo, 'Ensalada', 'Maria Lopez', cuenta_a.nombre, 1]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.where(fecha: fecha).count).to eq(2)
    end
  end

  # ===========================================================================
  # Error handling: does NOT create pedidos when rows have errors
  # ===========================================================================
  describe 'error handling stops pedido creation' do
    it 'does not create any pedidos when a row has an error' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1],
                                    ['INVALID', 'No existe', 'Maria Lopez', cuenta_a.nombre, 1]
                                  ])
      initial_count = Pedidos::Pedido.count
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(Pedidos::Pedido.count).to eq(initial_count)
      expect(importer.progreso.error?).to be true
    end
  end

  # ===========================================================================
  # Progress tracking
  # ===========================================================================
  describe 'progress tracking' do
    it 'tracks progress through Progreso' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_a.nombre, 1],
                                    [producto_b.codigo, 'Ensalada', 'Maria Lopez', cuenta_a.nombre, 1]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)
      expect(importer.progreso).to be_termino
      expect(importer.progreso.pje).to eq(100)
    end
  end

  # ===========================================================================
  # Complex real-world scenario
  # ===========================================================================
  describe 'complex real-world scenario' do
    it 'handles multi-employee, multi-product, multi-cuenta file' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'juan perez', cuenta_a.nombre, 2],
                                    [producto_b.codigo, 'Ensalada', 'juan perez', cuenta_a.nombre, 1],
                                    [producto_a.codigo, 'Milanesa', 'maria lopez', cuenta_a.nombre, 1],
                                    [producto_b.codigo, 'Ensalada', 'carlos ruiz', cuenta_b.nombre, 3]
                                  ])
      importer = create_importer(file.path)
      importer.run(file.path)

      all_imported = Pedidos::Pedido.where(fecha: fecha)
      expect(all_imported.count).to eq(3)

      juan = all_imported.find_by(para: 'Juan Perez')
      expect(juan.productos_solicitados.size).to eq(2)
      expect(juan.productos_solicitados.find_by(producto: producto_a).cantidad).to eq(2)

      carlos = all_imported.find_by(para: 'Carlos Ruiz')
      expect(carlos.cuenta).to eq(cuenta_b)
      expect(carlos.productos_solicitados.first.cantidad).to eq(3)
    end
  end
end
