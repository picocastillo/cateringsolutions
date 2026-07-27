require 'rails_helper'

RSpec.describe 'Pedidos Importar', type: :request do
  # Default Rails test host is www.example.com; request.domain(2) returns 'www.example.com'
  let(:tienda) { create(:tienda, nombre: 'Tienda Import Test', carrito_de_compras: true, dominio: 'www.example.com') }
  let(:cliente) { create(:cliente, tienda: tienda) }
  let(:cuenta_sucursal_a) { create(:cuenta, cliente: cliente, nombre: 'Sucursal A') }
  let(:cuenta_sucursal_b) { create(:cuenta, cliente: cliente, nombre: 'Sucursal B') }
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
    login_as(admin_user)
  end

  # ---------------------------------------------------------------------------
  # Helper: build an in-memory Excel workbook via Roo-compatible structure
  # ---------------------------------------------------------------------------
  def build_excel_file(rows)
    require 'write_xlsx'
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

  def upload_file(file)
    Rack::Test::UploadedFile.new(file.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
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

  def do_importar(file: nil, cliente_id: cliente.id, fecha_param: fecha)
    params = {
      cliente_id: cliente_id,
      fecha: fecha_param.to_s
    }
    params[:proceso] = { adjunto: upload_file(file) } if file
    post importar_pedidos_path, params: params
  end

  # ===========================================================================
  # Missing / Invalid params
  # ===========================================================================
  describe 'when required params are missing' do
    it 'redirects with error when no file is attached' do
      do_importar(fecha_param: fecha)
      expect(response).to redirect_to(pedidos_path)
      follow_redirect!
      expect(flash[:error]).to eq('Debe seleccionar Cuenta existente y adjuntar el XLS')
    end

    it 'redirects with error when cliente_id is missing' do
      file = build_standard_excel([['MIL001', 'Milanesa', 'Juan Perez', 'Sucursal A', 1]])
      do_importar(file: file, cliente_id: nil, fecha_param: fecha)
      expect(response).to redirect_to(pedidos_path)
      follow_redirect!
      expect(flash[:error]).to eq('Debe seleccionar Cuenta existente y adjuntar el XLS')
    end

    it 'redirects with error when fecha is missing' do
      file = build_standard_excel([['MIL001', 'Milanesa', 'Juan Perez', 'Sucursal A', 1]])
      params = { cliente_id: cliente.id, proceso: { adjunto: upload_file(file) } }
      post importar_pedidos_path, params: params
      expect(response).to redirect_to(pedidos_path)
      follow_redirect!
      expect(flash[:error]).to eq('Debe seleccionar Cuenta existente y adjuntar el XLS')
    end

    it 'redirects with error when cliente does not exist' do
      file = build_standard_excel([['MIL001', 'Milanesa', 'Juan Perez', 'Sucursal A', 1]])
      do_importar(file: file, cliente_id: 999_999, fecha_param: fecha)
      expect(response).to redirect_to(pedidos_path)
      follow_redirect!
      expect(flash[:error]).to eq('Debe seleccionar Cuenta existente y adjuntar el XLS')
    end
  end

  # ===========================================================================
  # Background processing (Proceso creation + job enqueue)
  # ===========================================================================
  describe 'background processing' do
    it 'creates a PedidosImporter proceso' do
      file = build_standard_excel([[producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1]])
      expect do
        do_importar(file: file)
      end.to change(Pedidos::PedidosImporter, :count).by(1)
    end

    it 'saves the proceso with correct params' do
      file = build_standard_excel([[producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1]])
      do_importar(file: file)
      proceso = Pedidos::PedidosImporter.last
      expect(proceso.autor).to eq(admin_user)
      expect(proceso.tienda).to eq(tienda)
      expect(proceso.params['cliente_id']).to eq(cliente.id)
      expect(proceso.params['fecha']).to eq(fecha.to_s)
      expect(proceso.adjunto_file_name).to be_present
    end

    it 'enqueues LanzarProcesoJob' do
      file = build_standard_excel([[producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1]])
      expect do
        do_importar(file: file)
      end.to have_enqueued_job(Infraestructura::Procesos::LanzarProcesoJob)
    end

    it 'redirects to pedidos_path with progress link' do
      file = build_standard_excel([[producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1]])
      do_importar(file: file)
      expect(response).to redirect_to(pedidos_path)
      expect(flash[:notice]).to include('segundo plano')
      expect(flash[:notice]).to include('Ver progreso')
    end
  end

  # ===========================================================================
  # End-to-end: run importer inline to verify full pipeline
  # ===========================================================================
  describe 'end-to-end import (inline execution)' do
    before do
      allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante)
      allow_any_instance_of(Pedidos::Pedido).to receive(:updatear_avisos_cocina)
      allow_any_instance_of(Pedidos::Pedido).to receive(:confirmar!) do |pedido|
        pedido.no_validar_fecha = true
        pedido.estado_id = 3
        pedido.save!
      end
    end

    it 'creates pedidos when the proceso is performed' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1],
                                    [producto_b.codigo, 'Ensalada', 'Maria Lopez', cuenta_sucursal_b.nombre, 1]
                                  ])
      do_importar(file: file)
      Pedidos::PedidosImporter.last.perform

      pedidos = Pedidos::Pedido.where(fecha: fecha)
      expect(pedidos.count).to eq(2)
      expect(pedidos.pluck(:para).sort).to eq(['Juan Perez', 'Maria Lopez'])
    end

    it 'groups rows by employee into single pedidos' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'juan perez', cuenta_sucursal_a.nombre, 2],
                                    [producto_b.codigo, 'Ensalada', 'juan perez', cuenta_sucursal_a.nombre, 1]
                                  ])
      do_importar(file: file)
      Pedidos::PedidosImporter.last.perform

      pedidos = Pedidos::Pedido.where(fecha: fecha, para: 'Juan Perez')
      expect(pedidos.count).to eq(1)
      expect(pedidos.first.productos_solicitados.size).to eq(2)
    end

    it 'sets correct pedido attributes' do
      file = build_standard_excel([[producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1]])
      do_importar(file: file)
      Pedidos::PedidosImporter.last.perform

      pedido = Pedidos::Pedido.last
      expect(pedido.pedido_para_empresa).to be true
      expect(pedido.autor).to eq(admin_user)
      expect(pedido.tienda).to eq(tienda)
      expect(pedido.usuario_id).to be_nil
      expect(pedido.cuenta).to eq(cuenta_sucursal_a)
      expect(pedido.estado_id).to eq(3)
    end

    it 'uses correct prices from buscar_precio' do
      file = build_standard_excel([[producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1]])
      do_importar(file: file)
      Pedidos::PedidosImporter.last.perform

      expect(Pedidos::Pedido.last.productos_solicitados.first.precio_unitario).to eq(500.0)
    end

    it 'handles multiple cuentas in same file' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1],
                                    [producto_b.codigo, 'Ensalada', 'Maria Lopez', cuenta_sucursal_b.nombre, 1]
                                  ])
      do_importar(file: file)
      Pedidos::PedidosImporter.last.perform

      expect(Pedidos::Pedido.find_by(para: 'Juan Perez').cuenta).to eq(cuenta_sucursal_a)
      expect(Pedidos::Pedido.find_by(para: 'Maria Lopez').cuenta).to eq(cuenta_sucursal_b)
    end

    it 'finds product by codigos_externos' do
      producto_a.update_column(:codigos_externos, 'EXT100, EXT200')
      file = build_standard_excel([['EXT100', 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1]])
      do_importar(file: file)
      Pedidos::PedidosImporter.last.perform

      expect(Pedidos::Pedido.last.productos_solicitados.first.producto).to eq(producto_a)
    end

    it 'skips empty rows' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1],
                                    [nil, nil, nil, nil, nil],
                                    [producto_b.codigo, 'Ensalada', 'Maria Lopez', cuenta_sucursal_a.nombre, 1]
                                  ])
      do_importar(file: file)
      Pedidos::PedidosImporter.last.perform

      expect(Pedidos::Pedido.where(fecha: fecha).count).to eq(2)
    end

    it 'accumulates quantity for same employee + same product' do
      file = build_standard_excel([
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 2],
                                    [producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1]
                                  ])
      do_importar(file: file)
      Pedidos::PedidosImporter.last.perform

      ps = Pedidos::Pedido.last.productos_solicitados.find_by(producto: producto_a)
      expect(ps.cantidad).to eq(3)
    end
  end

  # ===========================================================================
  # Error scenarios (recorded in progreso, not raised)
  # ===========================================================================
  describe 'error handling in background' do
    before do
      allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante)
      allow_any_instance_of(Pedidos::Pedido).to receive(:updatear_avisos_cocina)
      allow_any_instance_of(Pedidos::Pedido).to receive(:confirmar!) do |pedido|
        pedido.no_validar_fecha = true
        pedido.estado_id = 3
        pedido.save!
      end
    end

    it 'raises error for date mismatch' do
      wrong_date = fecha + 5.days
      file = build_standard_excel(
        [['MIL001', 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1]],
        date: wrong_date
      )
      do_importar(file: file, fecha_param: fecha)
      proceso = Pedidos::PedidosImporter.last
      expect { proceso.perform }.to raise_error(ErrorAplicacion, /no coincide con la fecha/)
    end

    it 'records error for invalid cuenta and does not create pedidos' do
      file = build_standard_excel([['MIL001', 'Milanesa', 'Juan Perez', 'Inexistente', 1]])
      do_importar(file: file)
      proceso = Pedidos::PedidosImporter.last
      proceso.perform

      expect(proceso.progreso.error?).to be true
      expect(Pedidos::Pedido.where(fecha: fecha).count).to eq(0)
    end

    it 'records error for non-existent product code' do
      file = build_standard_excel([['INVALID', 'No existe', 'Juan Perez', cuenta_sucursal_a.nombre, 1]])
      do_importar(file: file)
      proceso = Pedidos::PedidosImporter.last
      proceso.perform

      expect(proceso.progreso.error?).to be true
      expect(proceso.progreso.errores.first).to include('No existe ningún producto activo')
    end

    it 'records error for missing price' do
      create(:producto, tienda: tienda, categoria: categoria,
                        nombre: 'Sin Precio', codigo: 'SP001')
      file = build_standard_excel([['SP001', 'Sin Precio', 'Juan Perez', cuenta_sucursal_a.nombre, 1]])
      do_importar(file: file)
      proceso = Pedidos::PedidosImporter.last
      proceso.perform

      expect(proceso.progreso.error?).to be true
      expect(proceso.progreso.errores.first).to include('No existen precios activos')
    end

    it 'records error for duplicate pedidos' do
      existing = Pedidos::Pedido.new(
        tienda: tienda, cuenta: cuenta_sucursal_a, fecha: fecha,
        estado_id: 2, pedido_para_empresa: true, autor: admin_user,
        usuario_id: nil, para: 'Existing', no_validar_fecha: true
      )
      existing.productos_solicitados.build(producto: producto_a, cantidad: 1, precio_unitario: 500.0)
      existing.save!

      file = build_standard_excel([[producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1]])
      do_importar(file: file)
      proceso = Pedidos::PedidosImporter.last
      proceso.perform

      expect(proceso.progreso.error?).to be true
      expect(proceso.progreso.errores.first).to include('Ya se registran pedidos cargados')
    end
  end

  # ===========================================================================
  # Authorization
  # ===========================================================================
  describe 'authorization' do
    it 'denies access to non-admin users' do
      cliente_user = create(:usuario, :cliente, visualizando_tienda: tienda)
      login_as(cliente_user)
      file = build_standard_excel([[producto_a.codigo, 'Milanesa', 'Juan Perez', cuenta_sucursal_a.nombre, 1]])
      do_importar(file: file)
      expect(response).to have_http_status(:forbidden).or have_http_status(:redirect)
    end
  end
end
