require 'rails_helper'

RSpec.describe Pedidos::Pedido, type: :model do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Pedido', maneja_stock: true) }
  let(:cliente) { Clientes::Cliente.create!(nombre: 'Cliente Pedido', cuit: '20294834487', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: tienda) }
  let(:cuenta) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Cuenta Pedido') }
  let(:usuario) do
    Usuarios::Usuario.create!(
      nombre: 'Usuario Pedido',
      login: 'usuariopedido',
      password: 'password123',
      password_confirmation: 'password123',
      email: 'pedido@example.com',
      tipo_usuario_id: 1,
      dni: 12_345_678,
      cuenta: cuenta
    )
  end
  let(:valid_fecha) do
    # Set to the next available weekday (not Saturday or Sunday)
    d = Time.zone.today + 1
    d += 1 while d.saturday? || d.sunday?
    d
  end

  let(:pedido) do
    described_class.new(
      usuario: usuario,
      autor: usuario,
      cuenta: cuenta,
      fecha: valid_fecha,
      estado_id: 1,
      tienda: tienda
    )
  end

  it 'is valid with valid attributes' do
    expect(pedido).to be_valid
  end

  it 'requires cuenta only unless pendiente? is true' do
    # Should be invalid if pendiente? is false
    allow(pedido).to receive(:pendiente?).and_return(false)
    pedido.cuenta = nil
    expect(pedido).not_to be_valid
    expect(pedido.errors[:cuenta]).to be_present

    # Should be valid if pendiente? is true
    allow(pedido).to receive(:pendiente?).and_return(true)
    pedido.cuenta = nil
    pedido.valid?
    expect(pedido.errors[:cuenta]).to be_blank
  end

  it 'requires fecha only unless pendiente? is true' do
    # Should be invalid if pendiente? is false
    allow(pedido).to receive(:pendiente?).and_return(false)
    pedido.fecha = nil
    expect(pedido).not_to be_valid
    expect(pedido.errors[:fecha]).to be_present

    # Should be valid if pendiente? is true
    allow(pedido).to receive(:pendiente?).and_return(true)
    pedido.fecha = nil
    pedido.valid?
    expect(pedido.errors[:fecha]).to be_blank
  end

  it 'to_s returns a string' do
    expect(pedido.to_s).to be_a(String)
  end

  it 'returns correct estado_id' do
    expect(pedido.estado_id).to eq 1
  end

  it 'can be confirmed if productos_solicitados present' do
    categoria = Productos::Categoria.create!(nombre: 'Categoria Test', tienda: tienda)
    producto = Productos::Producto.create!(nombre: 'Producto Test', categoria: categoria, tienda: tienda)
    tipo = Comprobantes::Tipo.create!(desc: 'Factura', codigo: 1, clase: 'Ventas::Facturacion::Factura', letra: 'A')
    comprobante_double = Ventas::Facturacion::Comprobante.new(tipo: tipo, cuenta: cuenta, tienda: tienda)
    def comprobante_double.asignar_tipo; end
    double_ps = double('ProductoSolicitado', marked_for_destruction?: false, producto: producto, cantidad: 1, precio_unitario: 1, peso: nil, to_s: 'Producto')
    comprobantes_assoc = double('ComprobantesAssociation')
    allow(comprobantes_assoc).to receive_messages(select: [], where: double(order: double(first: comprobante_double)), reload: comprobantes_assoc, any?: false)
    allow(pedido).to receive_messages(productos_solicitados: [double_ps], comprobantes: comprobantes_assoc)
    pedido.save(validate: false) # Save pedido before confirming
    expect { pedido.confirmar! if pedido.productos_solicitados.present? }.not_to raise_error
  end

  it 'returns false for facturado by default' do
    expect(pedido.facturado).to be false
  end

  it 'returns false for envio_a_domicilio by default' do
    expect(pedido.envio_a_domicilio).to be false
  end

  it 'returns correct cuenta' do
    expect(pedido.cuenta).to eq cuenta
  end

  it 'returns correct usuario' do
    expect(pedido.usuario).to eq usuario
  end

  it 'returns correct autor' do
    expect(pedido.autor).to eq usuario
  end

  it 'returns correct tienda' do
    expect(pedido.tienda).to eq tienda
  end

  it 'returns correct estado_id after update' do
    pedido.estado_id = 2
    expect(pedido.estado_id).to eq 2
  end

  it 'returns correct fecha' do
    expect(pedido.fecha).to eq valid_fecha
  end

  it 'returns correct productos_solicitados' do
    expect(pedido.productos_solicitados).to eq []
  end

  it 'returns correct pedidos_creados for usuario' do
    pedido.save!
    expect(usuario.pedidos_creados).to include(pedido)
  end

  it 'requires usuario only when cuando_validar_usuario? is true' do
    # Should be invalid if cuando_validar_usuario? is true
    allow(pedido).to receive(:cuando_validar_usuario?).and_return(true)
    pedido.usuario = nil
    expect(pedido).not_to be_valid
    expect(pedido.errors[:usuario]).to be_present

    # Should be valid if cuando_validar_usuario? is false
    allow(pedido).to receive(:cuando_validar_usuario?).and_return(false)
    pedido.usuario = nil
    pedido.valid?
    expect(pedido.errors[:usuario]).to be_blank
  end

  describe '#codigo_s' do
    it 'returns formatted string' do
      pedido.save!
      expect(pedido.codigo_s).to be_a(String)
      expect(pedido.codigo_s).to include('Pedido')
    end
  end

  describe '#tipo_pedido' do
    it 'returns 2 for empresa' do
      pedido.pedido_para_empresa = true
      expect(pedido.tipo_pedido).to eq(2)
    end

    it 'returns 1 for individual' do
      pedido.pedido_para_empresa = false
      expect(pedido.tipo_pedido).to eq(1)
    end
  end

  describe '#tipo_pedido=' do
    it 'sets pedido_para_empresa to true for tipo 2' do
      pedido.tipo_pedido = 2
      expect(pedido.pedido_para_empresa).to be true
    end

    it 'sets pedido_para_empresa to false for tipo 1' do
      pedido.tipo_pedido = 1
      expect(pedido.pedido_para_empresa).to be false
    end
  end

  describe '#confirmar_y_crear_pago' do
    it 'responds to method with correct arguments' do
      pedido.save!
      expect(pedido).to respond_to(:confirmar_y_crear_pago)
    end
  end

  describe '.fecha_desde scope' do
    it 'filters by start date' do
      pedido.fecha = Time.zone.today
      pedido.save(validate: false)
      result = described_class.fecha_desde(Time.zone.today)
      expect(result).to include(pedido)
    end
  end

  describe '.fecha_hasta scope' do
    it 'filters by end date' do
      pedido.fecha = Time.zone.today
      pedido.save(validate: false)
      result = described_class.fecha_hasta(Time.zone.today)
      expect(result).to include(pedido)
    end
  end

  describe '#pendiente?' do
    it 'returns true when estado_id is 1' do
      pedido.estado_id = 1
      expect(pedido.pendiente?).to be true
    end

    it 'returns false when estado_id is not 1' do
      pedido.estado_id = 2
      expect(pedido.pendiente?).to be false
    end
  end

  describe 'estado methods' do
    it 'tracks estado_id' do
      expect(pedido.estado_id).to eq(1)
      pedido.estado_id = 2
      expect(pedido.estado_id).to eq(2)
    end
  end

  describe '#aceptar and #confirmar! stock movement' do
    let(:categoria) { Productos::Categoria.create!(nombre: 'Categoria Test', tienda: tienda, stock_activo: true) }
    let(:producto) { Productos::Producto.create!(nombre: 'Producto Test', categoria: categoria, tienda: tienda) }
    let(:producto_solicitado) do
      ps = Productos::ProductoSolicitado.new(
        pedido: pedido,
        producto: producto,
        cantidad: 5,
        precio_unitario: 100
      )
      ps.save(validate: false)
      ps
    end
    let(:local) do
      Locales::Local.create!(
        nombre: 'Local Test',
        tienda: tienda,
        domicilio: 'Calle Test 123',
        telefono: '123456789'
      )
    end
    let!(:stock) do
      # Ensure stock for the producto in the local
      existing = producto.stock_for_local(local.id)
      if existing
        existing.update!(cantidad_actual: 100, cantidad_minima: 10)
        existing
      else
        Productos::Stock.create!(
          producto: producto,
          tienda: tienda,
          local: local,
          cantidad_actual: 100,
          cantidad_minima: 10
        )
      end
    end

    before do
      pedido.autor = usuario
      pedido.local = local
      pedido.productos_solicitados << producto_solicitado
      pedido.save(validate: false)
    end

    context 'when stock movement happens in aceptar!' do
      before do
        # Simulate stock reduction in aceptar!
        producto.reducir_stock(5, local.id, 'pedido_aceptado')
        pedido.update_column(:stock_reducido, true)
      end

      it 'does not duplicate stock movement in confirmar!' do
        initial_stock = producto.stock_for_local(local.id).cantidad_actual

        # Create comprobante double to avoid full facturacion logic
        tipo = Comprobantes::Tipo.create!(desc: 'Factura', codigo: 1, clase: 'Ventas::Facturacion::Factura', letra: 'A')
        comprobante = Ventas::Facturacion::Comprobante.new(tipo: tipo, cuenta: cuenta, tienda: tienda)
        def comprobante.asignar_tipo; end

        comprobantes_assoc = double('ComprobantesAssociation')
        allow(comprobantes_assoc).to receive_messages(select: [], where: double(order: double(first: comprobante)), reload: comprobantes_assoc, any?: false)
        allow(pedido).to receive(:comprobantes).and_return(comprobantes_assoc)
        allow(comprobante).to receive(:confirmar!)
        allow(comprobante).to receive(:valid?).and_return(true)

        pedido.confirmar!(usuario)

        # Stock should remain the same since it was already reduced in aceptar!
        final_stock = producto.stock_for_local(local.id).cantidad_actual
        expect(final_stock).to eq(initial_stock)
      end
    end

    context 'when stock movement did NOT happen in aceptar!' do
      it 'reduces stock in confirmar!' do
        initial_stock = producto.stock_for_local(local.id).cantidad_actual

        # Skip facturacion callbacks for this test
        allow(pedido).to receive(:crear_comprobante)

        pedido.confirmar!(usuario)

        # Stock should be reduced by the cantidad_solicitada
        final_stock = producto.stock_for_local(local.id).cantidad_actual
        expect(final_stock).to eq(initial_stock - 5)
      end

      it 'creates stock movement record with correct tipo' do
        # Skip facturacion callbacks for this test
        allow(pedido).to receive(:crear_comprobante)

        expect do
          pedido.confirmar!(usuario)
        end.to change(Productos::StockMovimiento, :count).by(1)

        movement = Productos::StockMovimiento.last
        expect(movement.tipo).to eq('salida')
        expect(movement.cantidad).to eq(5)
        expect(movement.stock.local).to eq(local)
      end

      it 'handles multiple productos_solicitados' do
        producto2 = Productos::Producto.create!(nombre: 'Producto Test 2', categoria: categoria, tienda: tienda)
        stock2 = producto2.stock_for_local(local.id)
        stock_attrs = { cantidad_actual: 100, cantidad_minima: 10 }
        if stock2
          stock2.update!(stock_attrs)
        else
          Productos::Stock.create!(stock_attrs.merge(producto: producto2, tienda: tienda, local: local))
        end

        ps2 = Productos::ProductoSolicitado.new(
          pedido: pedido, producto: producto2, cantidad: 3, precio_unitario: 200
        )
        ps2.save(validate: false)

        initial_stock1 = producto.stock_for_local(local.id).cantidad_actual
        initial_stock2 = producto2.stock_for_local(local.id).cantidad_actual
        allow(pedido).to receive(:crear_comprobante)

        pedido.confirmar!(usuario)

        expect(producto.stock_for_local(local.id).cantidad_actual).to eq(initial_stock1 - 5)
        expect(producto2.stock_for_local(local.id).cantidad_actual).to eq(initial_stock2 - 3)
      end
    end

    context 'when stock is insufficient' do
      it 'handles insufficient stock gracefully' do
        # Set stock to less than required
        producto.stock_for_local(local.id).update!(cantidad_actual: 2)

        # Skip facturacion callbacks for this test
        allow(pedido).to receive(:crear_comprobante)

        # Should handle insufficient stock gracefully (reducir_stock returns false but doesn't raise)
        expect do
          pedido.confirmar!(usuario)
        end.not_to raise_error

        # Stock should not change since there wasn't enough
        expect(producto.stock_for_local(local.id).cantidad_actual).to eq(2)
      end
    end
  end

  describe '#reducir_stock_si_necesario with different locals' do
    let(:categoria) { Productos::Categoria.create!(nombre: 'Cat Multi-Local', tienda: tienda, stock_activo: true) }
    let(:producto) { Productos::Producto.create!(nombre: 'Producto Multi-Local', categoria: categoria, tienda: tienda) }
    let(:local_a) do
      Locales::Local.create!(nombre: 'Local A', tienda: tienda, domicilio: 'Calle A 100', telefono: '111111')
    end
    let(:local_b) do
      Locales::Local.create!(nombre: 'Local B', tienda: tienda, domicilio: 'Calle B 200', telefono: '222222')
    end

    let!(:stock_local_a) do
      existing = producto.stock_for_local(local_a.id)
      if existing
        existing.update!(cantidad_actual: 50, cantidad_minima: 5)
        existing
      else
        Productos::Stock.create!(producto: producto, tienda: tienda, local: local_a,
                                 cantidad_actual: 50, cantidad_minima: 5)
      end
    end

    let!(:stock_local_b) do
      existing = producto.stock_for_local(local_b.id)
      if existing
        existing.update!(cantidad_actual: 10, cantidad_minima: 2)
        existing
      else
        Productos::Stock.create!(producto: producto, tienda: tienda, local: local_b,
                                 cantidad_actual: 10, cantidad_minima: 2)
      end
    end

    it 'reduces stock only in the assigned local' do
      pedido.local = local_a
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 5, precio_unitario: 100)
      ps.save(validate: false)
      pedido.save(validate: false)
      allow(pedido).to receive(:crear_comprobante)

      pedido.reducir_stock_si_necesario

      stock_local_a.reload
      stock_local_b.reload
      expect(stock_local_a.cantidad_actual).to eq(45)
      expect(stock_local_b.cantidad_actual).to eq(10) # unchanged
    end

    it 'reduces stock in local_b when pedido is assigned to local_b' do
      pedido.local = local_b
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 3, precio_unitario: 100)
      ps.save(validate: false)
      pedido.save(validate: false)
      allow(pedido).to receive(:crear_comprobante)

      pedido.reducir_stock_si_necesario

      stock_local_a.reload
      stock_local_b.reload
      expect(stock_local_a.cantidad_actual).to eq(50) # unchanged
      expect(stock_local_b.cantidad_actual).to eq(7)
    end

    it 'reduces main stock (nil local) when pedido has no local' do
      # Create main stock
      main_stock = Productos::Stock.find_or_create_by!(producto: producto, tienda: tienda, local_id: nil) do |s|
        s.cantidad_actual = 80
        s.cantidad_minima = 5
      end
      main_stock.update!(cantidad_actual: 80)

      pedido.local = nil
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 7, precio_unitario: 100)
      ps.save(validate: false)
      pedido.save(validate: false)
      allow(pedido).to receive(:crear_comprobante)

      pedido.reducir_stock_si_necesario

      main_stock.reload
      stock_local_a.reload
      stock_local_b.reload
      expect(main_stock.cantidad_actual).to eq(73)
      expect(stock_local_a.cantidad_actual).to eq(50) # unchanged
      expect(stock_local_b.cantidad_actual).to eq(10) # unchanged
    end

    it 'does not reduce stock when tienda does not maneja_stock' do
      tienda.update_column(:maneja_stock, false)

      pedido.local = local_a
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 5, precio_unitario: 100)
      ps.save(validate: false)
      pedido.save(validate: false)

      pedido.reducir_stock_si_necesario

      stock_local_a.reload
      expect(stock_local_a.cantidad_actual).to eq(50) # unchanged
      expect(pedido.stock_reducido).to be false
    end

    it 'does not reduce stock for categories without stock_activo' do
      cat_sin_stock = Productos::Categoria.create!(nombre: 'Sin Stock Ctrl', tienda: tienda, stock_activo: false)
      prod_sin_stock = Productos::Producto.create!(nombre: 'Prod Sin Stock', categoria: cat_sin_stock, tienda: tienda)

      pedido.local = local_a
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: prod_sin_stock, cantidad: 5, precio_unitario: 100)
      ps.save(validate: false)
      pedido.save(validate: false)
      allow(pedido).to receive(:crear_comprobante)

      pedido.reducir_stock_si_necesario

      stock_local_a.reload
      expect(stock_local_a.cantidad_actual).to eq(50) # unchanged
      expect(pedido.stock_reducido).to be true # still marked as reduced (ran through logic)
    end
  end

  describe '#reducir_stock_si_necesario with pesable products' do
    let(:categoria) { Productos::Categoria.create!(nombre: 'Cat Pesable', tienda: tienda, stock_activo: true) }
    let(:producto) { Productos::Producto.create!(nombre: 'Prod Pesable', categoria: categoria, tienda: tienda, pesable: true) }
    let(:local_pesable) do
      Locales::Local.create!(nombre: 'Local Pesable', tienda: tienda, domicilio: 'Calle P 100', telefono: '444444')
    end

    let!(:stock_pesable) do
      existing = producto.stock_for_local(local_pesable.id)
      if existing
        existing.update!(cantidad_actual: 100, cantidad_minima: 5)
        existing
      else
        Productos::Stock.create!(producto: producto, tienda: tienda, local: local_pesable,
                                 cantidad_actual: 100, cantidad_minima: 5)
      end
    end

    it 'reduces stock by peso for pesable products (cantidad always 1)' do
      pedido.local = local_pesable
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 1, precio_unitario: 500, peso: 3.0)
      ps.save(validate: false)
      pedido.save(validate: false)
      allow(pedido).to receive(:crear_comprobante)

      pedido.reducir_stock_si_necesario

      stock_pesable.reload
      # 1 * 3.0 = 3.0 kg reduced
      expect(stock_pesable.cantidad_actual).to eq(97)
    end

    it 'reduces stock by cantidad alone when peso is nil' do
      pedido.local = local_pesable
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 5, precio_unitario: 100, peso: nil)
      ps.save(validate: false)
      pedido.save(validate: false)
      allow(pedido).to receive(:crear_comprobante)

      pedido.reducir_stock_si_necesario

      stock_pesable.reload
      expect(stock_pesable.cantidad_actual).to eq(95)
    end

    it 'handles mixed pesable and non-pesable products' do
      cat_normal = Productos::Categoria.create!(nombre: 'Cat Normal Mix', tienda: tienda, stock_activo: true)
      prod_normal = Productos::Producto.create!(nombre: 'Prod Normal', categoria: cat_normal, tienda: tienda, pesable: false)
      stock_normal = Productos::Stock.create!(producto: prod_normal, tienda: tienda, local: local_pesable,
                                              cantidad_actual: 100, cantidad_minima: 5)

      pedido.local = local_pesable
      ps_pesable = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 1, precio_unitario: 500, peso: 2.0)
      ps_pesable.save(validate: false)
      ps_normal = Productos::ProductoSolicitado.new(pedido: pedido, producto: prod_normal, cantidad: 3, precio_unitario: 100, peso: nil)
      ps_normal.save(validate: false)
      pedido.save(validate: false)
      allow(pedido).to receive(:crear_comprobante)

      pedido.reducir_stock_si_necesario

      stock_pesable.reload
      stock_normal.reload
      expect(stock_pesable.cantidad_actual).to eq(98) # 100 - (1 * 2.0)
      expect(stock_normal.cantidad_actual).to eq(97)  # 100 - 3
    end
  end

  describe '#importe_total with pesable products' do
    it 'calculates total including peso (cantidad always 1)' do
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: nil, cantidad: 1, precio_unitario: 500, peso: 1.5)
      allow(pedido).to receive_messages(productos_solicitados: [ps], tiene_descuento_cupon?: false)

      # 1 * 1.5 * 500 = 750
      expect(pedido.importe_total.to_f).to eq(750.0)
    end

    it 'mixes pesable and non-pesable in total' do
      ps_pesable = Productos::ProductoSolicitado.new(pedido: pedido, producto: nil, cantidad: 1, precio_unitario: 1000, peso: 0.5)
      ps_normal = Productos::ProductoSolicitado.new(pedido: pedido, producto: nil, cantidad: 3, precio_unitario: 200)

      allow(pedido).to receive_messages(productos_solicitados: [ps_pesable, ps_normal], tiene_descuento_cupon?: false)

      # (1 * 0.5 * 1000) + (3 * 200) = 500 + 600 = 1100
      expect(pedido.importe_total.to_f).to eq(1100.0)
    end
  end

  describe '#restaurar_stock_si_fue_reducido with locals' do
    let(:categoria) { Productos::Categoria.create!(nombre: 'Cat Restore', tienda: tienda, stock_activo: true) }
    let(:producto) { Productos::Producto.create!(nombre: 'Prod Restore', categoria: categoria, tienda: tienda) }
    let(:local_test) do
      Locales::Local.create!(nombre: 'Local Restore', tienda: tienda, domicilio: 'Calle R 300', telefono: '333333')
    end

    let!(:stock) do
      existing = producto.stock_for_local(local_test.id)
      if existing
        existing.update!(cantidad_actual: 50, cantidad_minima: 5)
        existing
      else
        Productos::Stock.create!(producto: producto, tienda: tienda, local: local_test,
                                 cantidad_actual: 50, cantidad_minima: 5)
      end
    end

    it 'restores stock in the correct local after cancellation' do
      pedido.local = local_test
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 10, precio_unitario: 100)
      ps.save(validate: false)
      pedido.save(validate: false)
      allow(pedido).to receive(:crear_comprobante)

      # Reduce stock first
      pedido.reducir_stock_si_necesario
      stock.reload
      expect(stock.cantidad_actual).to eq(40)

      # Restore stock
      pedido.restaurar_stock_si_fue_reducido
      stock.reload
      expect(stock.cantidad_actual).to eq(50)
      expect(pedido.stock_reducido).to be false
    end

    it 'creates devolucion movement in the correct local' do
      pedido.local = local_test
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 5, precio_unitario: 100)
      ps.save(validate: false)
      pedido.save(validate: false)
      allow(pedido).to receive(:crear_comprobante)

      pedido.reducir_stock_si_necesario

      expect do
        pedido.restaurar_stock_si_fue_reducido
      end.to change { stock.stock_movimientos.count }.by(1)

      last = stock.stock_movimientos.where(tipo: 'entrada').order(:id).last
      expect(last).to be_present
      expect(last.motivo).to include('devolucion')
      expect(last.cantidad).to eq(5)
    end
  end

  describe '#cancelar! stock restoration' do
    let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Pedido', maneja_stock: true) }
    let(:categoria) { Productos::Categoria.create!(nombre: 'Categoria Stock', tienda: tienda, stock_activo: true) }
    let(:producto) { Productos::Producto.create!(nombre: 'Producto Test', categoria: categoria, tienda: tienda) }
    let(:cliente) { Clientes::Cliente.create!(nombre: 'Cliente Pedido', cuit: '20294834487', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: tienda) }
    let(:cuenta) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Cuenta Pedido') }
    let(:usuario) do
      Usuarios::Usuario.create!(
        nombre: 'Usuario Pedido',
        login: 'usuariopedido_cancel',
        password: 'password123',
        password_confirmation: 'password123',
        email: 'pedido_cancel@example.com',
        tipo_usuario_id: 1,
        dni: 12_345_678,
        cuenta: cuenta
      )
    end
    let(:local) do
      Locales::Local.create!(
        nombre: 'Local Test',
        tienda: tienda,
        domicilio: 'Calle Test 123',
        telefono: '123456789'
      )
    end
    let!(:stock) do
      Productos::Stock.create!(
        producto: producto,
        tienda: tienda,
        local: local,
        cantidad_actual: 100,
        cantidad_minima: 10
      )
    end

    context 'when stock was reduced' do
      it 'restores stock when pedido is cancelled' do
        # Create pedido with valid future weekday
        fecha_valida = Date.current + 1
        fecha_valida += 1 while fecha_valida.saturday? || fecha_valida.sunday?

        pedido = build(:pedido, tienda: tienda, cuenta: cuenta, fecha: fecha_valida, estado_id: 1, autor: usuario, usuario: usuario, local: local)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta
        pedido.save!

        create(:producto_solicitado, pedido: pedido, producto: producto, cantidad: 15, precio_unitario: 100)

        initial_stock = stock.cantidad_actual

        # Mock comprobante creation
        allow(pedido).to receive(:crear_comprobante)

        # Reduce stock (via aceptar! and confirmar!)
        pedido.aceptar!
        pedido.confirmar!(usuario)

        stock.reload
        reduced_stock = stock.cantidad_actual
        expect(reduced_stock).to eq(initial_stock - 15)
        expect(pedido.stock_reducido).to be true

        # Cancel pedido - should restore stock
        pedido.cancelar!

        stock.reload
        expect(stock.cantidad_actual).to eq(initial_stock) # Back to original
        expect(pedido.stock_reducido).to be false
      end

      it 'creates devolucion stock movement when cancelling' do
        # Create pedido with valid future weekday
        fecha_valida = Date.current + 1
        fecha_valida += 1 while fecha_valida.saturday? || fecha_valida.sunday?

        pedido = build(:pedido, tienda: tienda, cuenta: cuenta, fecha: fecha_valida, estado_id: 1, autor: usuario, usuario: usuario, local: local)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta
        pedido.save!

        create(:producto_solicitado, pedido: pedido, producto: producto, cantidad: 10, precio_unitario: 100)

        allow(pedido).to receive(:crear_comprobante)

        pedido.aceptar!
        pedido.confirmar!(usuario)

        initial_movimientos_count = stock.stock_movimientos.count

        # Cancel - should create devolucion movement
        pedido.cancelar!

        expect(stock.stock_movimientos.count).to eq(initial_movimientos_count + 1)
        last_movement = stock.stock_movimientos.where(tipo: 'entrada').order(:created_at).last
        expect(last_movement).to be_present
        expect(last_movement.motivo).to include('devolucion')
        expect(last_movement.cantidad).to eq(10)
      end
    end

    context 'when stock was not reduced' do
      it 'does nothing when cancelling pedido without stock reduction' do
        fecha_valida = Date.current + 1
        fecha_valida += 1 while fecha_valida.saturday? || fecha_valida.sunday?

        pedido = build(:pedido, tienda: tienda, cuenta: cuenta, fecha: fecha_valida, estado_id: 1, autor: usuario, usuario: usuario, local: local)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta
        pedido.save!

        create(:producto_solicitado, pedido: pedido, producto: producto, cantidad: 5, precio_unitario: 100)

        initial_stock = stock.cantidad_actual

        # Cancel without reducing stock
        pedido.cancelar!

        stock.reload
        expect(stock.cantidad_actual).to eq(initial_stock) # No change
      end
    end

    context 'when categoria does not have stock_activo' do
      let(:categoria_sin_stock) { Productos::Categoria.create!(nombre: 'Sin Stock', tienda: tienda, stock_activo: false) }
      let(:producto_sin_stock) { Productos::Producto.create!(nombre: 'Producto Sin Stock', categoria: categoria_sin_stock, tienda: tienda) }

      it 'does not restore stock for productos without stock_activo' do
        fecha_valida = Date.current + 1
        fecha_valida += 1 while fecha_valida.saturday? || fecha_valida.sunday?

        pedido = build(:pedido, tienda: tienda, cuenta: cuenta, fecha: fecha_valida, estado_id: 1, autor: usuario, usuario: usuario, local: local)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta
        pedido.save!

        # Add both productos
        create(:producto_solicitado, pedido: pedido, producto: producto, cantidad: 5, precio_unitario: 100)
        create(:producto_solicitado, pedido: pedido, producto: producto_sin_stock, cantidad: 3, precio_unitario: 100)

        allow(pedido).to receive(:crear_comprobante)

        initial_stock = stock.cantidad_actual

        pedido.aceptar!
        pedido.confirmar!(usuario)
        pedido.update_column(:stock_reducido, true)

        # Cancel - should only restore producto with stock_activo
        pedido.cancelar!

        stock.reload
        expect(stock.cantidad_actual).to eq(initial_stock) # Restored for producto with stock_activo
      end
    end
  end

  describe '#limite_compra_excedido?' do
    let(:categoria) { Productos::Categoria.create!(nombre: 'Cat Limite', tienda: tienda) }
    let(:producto) { Productos::Producto.create!(nombre: 'Prod Limite', categoria: categoria, tienda: tienda) }

    before do
      pedido.save!
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 10, precio_unitario: 200)
      ps.save(validate: false)
      pedido.productos_solicitados.reload
      pedido.flush_cache(:importe_total)
    end

    context 'when no limits are set' do
      it 'returns false' do
        expect(pedido.limite_compra_excedido?).to be false
      end
    end

    context 'with limite_compra_pesos' do
      it 'returns true when total exceeds limit' do
        cliente.update!(limite_compra_pesos: 1000)
        pedido.flush_cache(:importe_total)
        expect(pedido.importe_total.to_f).to eq(2000.0)
        expect(pedido.limite_compra_excedido?).to be true
      end

      it 'returns false when total is within limit' do
        cliente.update!(limite_compra_pesos: 5000)
        pedido.flush_cache(:importe_total)
        expect(pedido.limite_compra_excedido?).to be false
      end

      it 'returns false when total equals limit' do
        cliente.update!(limite_compra_pesos: 2000)
        pedido.flush_cache(:importe_total)
        expect(pedido.limite_compra_excedido?).to be false
      end
    end

    context 'with limite_compra_dolares' do
      before do
        Cotizaciones::Dolar.create!(fecha: pedido.fecha, precio_venta: 1425.0)
      end

      it 'returns true when total exceeds limit in dolares converted to pesos' do
        # Total is $2000, limit is US$1 = $1425 pesos
        cliente.update!(limite_compra_dolares: 1)
        pedido.flush_cache(:importe_total)
        expect(pedido.limite_compra_excedido?).to be true
      end

      it 'returns false when total is within limit in dolares' do
        # Total is $2000, limit is US$10 = $14250 pesos
        cliente.update!(limite_compra_dolares: 10)
        pedido.flush_cache(:importe_total)
        expect(pedido.limite_compra_excedido?).to be false
      end

      it 'returns false when no cotizacion exists' do
        Cotizaciones::Dolar.where(fecha: pedido.fecha).delete_all
        cliente.update!(limite_compra_dolares: 1)
        pedido.flush_cache(:importe_total)
        expect(pedido.limite_compra_excedido?).to be false
      end
    end

    context 'with both limits set' do
      before do
        Cotizaciones::Dolar.create!(fecha: pedido.fecha, precio_venta: 1425.0)
      end

      it 'checks pesos limit first' do
        # Total is $2000, pesos limit $1000 (exceeded), dolares limit US$10 = $14250 (not exceeded)
        cliente.update!(limite_compra_pesos: 1000, limite_compra_dolares: 10)
        pedido.flush_cache(:importe_total)
        expect(pedido.limite_compra_excedido?).to be true
        expect(pedido.mensaje_limite_compra_excedido).to include('$1000.00')
      end
    end

    context 'when pedido has no productos' do
      it 'returns false' do
        empty_pedido = described_class.new(
          usuario: usuario, autor: usuario, cuenta: cuenta,
          fecha: valid_fecha, estado_id: 1, tienda: tienda
        )
        expect(empty_pedido.limite_compra_excedido?).to be false
      end
    end
  end

  describe '#mensaje_limite_compra_excedido' do
    let(:categoria) { Productos::Categoria.create!(nombre: 'Cat Msg', tienda: tienda) }
    let(:producto) { Productos::Producto.create!(nombre: 'Prod Msg', categoria: categoria, tienda: tienda) }

    before do
      pedido.save!
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 5, precio_unitario: 300)
      ps.save(validate: false)
      pedido.productos_solicitados.reload
      pedido.flush_cache(:importe_total)
    end

    it 'returns nil when no limit is set' do
      expect(pedido.mensaje_limite_compra_excedido).to be_nil
    end

    it 'returns message with pesos amounts when pesos limit exceeded' do
      cliente.update!(limite_compra_pesos: 1000)
      pedido.flush_cache(:importe_total)
      msg = pedido.mensaje_limite_compra_excedido
      expect(msg).to include('1500.00')
      expect(msg).to include('1000.00')
      expect(msg).to include('supera el límite')
    end

    it 'returns message with dolares amounts when dolares limit exceeded' do
      Cotizaciones::Dolar.create!(fecha: pedido.fecha, precio_venta: 1000.0)
      cliente.update!(limite_compra_dolares: 1.0)
      pedido.flush_cache(:importe_total)
      msg = pedido.mensaje_limite_compra_excedido
      expect(msg).to include('US$1.00')
      expect(msg).to include('1500.00')
      expect(msg).to include('supera el límite')
    end

    it 'returns nil when no cuenta is set' do
      pedido_sin_cuenta = described_class.new(estado_id: 1, tienda: tienda, autor: usuario)
      allow(pedido_sin_cuenta).to receive(:importe_total).and_return(Danconia::Money.new(1000))
      expect(pedido_sin_cuenta.mensaje_limite_compra_excedido).to be_nil
    end
  end

  describe 'Cupon discount' do
    let(:categoria) { Productos::Categoria.create!(nombre: 'Cat Cupon', tienda: tienda) }
    let(:producto1) { Productos::Producto.create!(nombre: 'Prod A', categoria: categoria, tienda: tienda) }
    let(:producto2) { Productos::Producto.create!(nombre: 'Prod B', categoria: categoria, tienda: tienda) }

    let(:cupon_importe) { create(:cupon, tienda: tienda, tipo_descuento: 'importe', importe: 200) }
    let(:cupon_porcentaje) { create(:cupon, :porcentaje, tienda: tienda, porcentaje: 20, limite_bonificacion: 500) }

    before do
      # Create precios linked to the cliente so asignar_precio validation passes
      precio1 = create(:precio, producto: producto1, importe: 300, fecha_desde: 1.month.ago, fecha_hasta: 1.year.from_now)
      precio1.clientes << cliente unless precio1.clientes.include?(cliente)
      precio2 = create(:precio, producto: producto2, importe: 200, fecha_desde: 1.month.ago, fecha_hasta: 1.year.from_now)
      precio2.clientes << cliente unless precio2.clientes.include?(cliente)

      pedido.save!
      ps1 = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto1, cantidad: 2, precio_unitario: 300)
      ps1.save(validate: false)
      ps2 = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto2, cantidad: 3, precio_unitario: 200)
      ps2.save(validate: false)
      pedido.productos_solicitados.reload
    end

    describe '#aplicar_cupon!' do
      it 'sets cupon and distributes discount proportionally' do
        pedido.aplicar_cupon!(cupon_importe)

        pedido.productos_solicitados.reload
        expect(pedido.cupon).to eq(cupon_importe)
        pedido.productos_solicitados.each do |ps|
          expect(ps.precio_con_descuento).to be < ps.precio_unitario
        end
      end

      it 'calculates correct discounted prices for importe cupon' do
        # Total: 2*300 + 3*200 = 1200, discount: 200
        pedido.aplicar_cupon!(cupon_importe)

        pedido.productos_solicitados.reload
        ps1 = pedido.productos_solicitados.find_by(producto: producto1)
        ps2 = pedido.productos_solicitados.find_by(producto: producto2)

        # Prod A: proporcion = 600/1200 = 0.5, descuento_unitario = 200*0.5/2 = 50
        expect(ps1.precio_con_descuento).to eq(250) # 300 - 50
        # Prod B: proporcion = 600/1200 = 0.5, descuento_unitario = 200*0.5/3 = 33.33
        expect(ps2.precio_con_descuento).to eq(166.67) # 200 - 33.33
      end

      it 'calculates correct discounted prices for porcentaje cupon' do
        # Total: 1200, 20% = 240 (under 500 limit)
        pedido.aplicar_cupon!(cupon_porcentaje)

        pedido.productos_solicitados.reload
        total_con_descuento = pedido.productos_solicitados.sum { |ps| ps.precio_con_descuento * ps.cantidad }
        expect(total_con_descuento).to be_within(0.01).of(960) # 1200 - 240
      end

      it 'respects limite_bonificacion for porcentaje cupon' do
        cupon_limited = create(:cupon, :porcentaje, tienda: tienda, porcentaje: 50, limite_bonificacion: 100)
        # Total: 1200, 50% = 600, capped at 100
        pedido.aplicar_cupon!(cupon_limited)

        pedido.productos_solicitados.reload
        total_con_descuento = pedido.productos_solicitados.sum { |ps| ps.precio_con_descuento * ps.cantidad }
        expect(total_con_descuento).to be_within(0.01).of(1100) # 1200 - 100
      end

      it 'raises error for non-vigente cupon' do
        cupon_importe.update_column(:cancelado, true)
        expect { pedido.aplicar_cupon!(cupon_importe) }.to raise_error(RuntimeError, /vigentes/)
      end
    end

    describe '#quitar_cupon!' do
      before { pedido.aplicar_cupon!(cupon_importe) }

      it 'removes cupon and resets prices' do
        pedido.quitar_cupon!

        pedido.productos_solicitados.reload
        expect(pedido.cupon).to be_nil
        # sincronizar_precio_con_descuento sets precio_con_descuento = precio_unitario on save
        pedido.productos_solicitados.each do |ps|
          expect(ps.precio_con_descuento).to eq(ps.precio_unitario)
        end
      end

      it 'makes cupon reusable after removal' do
        pedido.quitar_cupon!

        expect(cupon_importe.reload.usado?).to be false
        expect(cupon_importe.vigente?).to be true
      end
    end

    describe '#tiene_descuento_cupon?' do
      it 'returns true when cupon is applied' do
        pedido.aplicar_cupon!(cupon_importe)
        expect(pedido.tiene_descuento_cupon?).to be true
      end

      it 'returns false without cupon' do
        expect(pedido.tiene_descuento_cupon?).to be false
      end

      it 'returns false after cupon removed' do
        pedido.aplicar_cupon!(cupon_importe)
        pedido.quitar_cupon!
        expect(pedido.tiene_descuento_cupon?).to be false
      end
    end

    describe '#importe_descuento_cupon' do
      it 'returns discount amount when cupon applied' do
        pedido.aplicar_cupon!(cupon_importe)
        pedido.flush_cache(:importe_total)
        expect(pedido.importe_descuento_cupon.to_f).to eq(200.0)
      end

      it 'returns zero without cupon' do
        expect(pedido.importe_descuento_cupon.to_f).to eq(0)
      end
    end

    describe '#reaplicar_cupon!' do
      it 'returns :none when no cupon is present' do
        expect(pedido.reaplicar_cupon!).to eq(:none)
      end

      it 'redistributes discount when a new product is added' do
        pedido.aplicar_cupon!(cupon_importe)

        # Add a new product (simulates adding after cupon was applied)
        producto3 = Productos::Producto.create!(nombre: 'Prod C', categoria: categoria, tienda: tienda)
        precio3 = create(:precio, producto: producto3, importe: 500, fecha_desde: 1.month.ago, fecha_hasta: 1.year.from_now)
        precio3.clientes << cliente
        ps3 = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto3, cantidad: 1, precio_unitario: 500)
        ps3.save(validate: false)
        pedido.productos_solicitados.reload

        result = pedido.reaplicar_cupon!

        expect(result).to eq(:ok)
        pedido.productos_solicitados.reload
        # All 3 products should have discount
        total_con_descuento = pedido.productos_solicitados.sum { |ps| ps.precio_con_descuento * ps.cantidad }
        # New total: 2*300 + 3*200 + 1*500 = 1700, discount 200 => 1500
        expect(total_con_descuento.to_f).to be_within(0.01).of(1500.0)
      end

      it 'removes cupon when it has expired' do
        pedido.aplicar_cupon!(cupon_importe)
        expect(pedido.cupon).to eq(cupon_importe)

        # Expire the cupon
        cupon_importe.update_column(:fecha_vencimiento, Date.current - 1.day)

        result = pedido.reaplicar_cupon!

        expect(result).to eq(:expired)
        expect(pedido.reload.cupon).to be_nil
        pedido.productos_solicitados.each do |ps|
          expect(ps.precio_con_descuento).to eq(ps.precio_unitario)
        end
      end

      it 'removes cupon when it has been cancelled' do
        pedido.aplicar_cupon!(cupon_importe)
        cupon_importe.update_column(:cancelado, true)

        result = pedido.reaplicar_cupon!

        expect(result).to eq(:expired)
        expect(pedido.reload.cupon).to be_nil
      end

      it 'recalculates correctly when product quantity changes' do
        pedido.aplicar_cupon!(cupon_importe)
        # Original: 2*300 + 3*200 = 1200, discount 200 => 1000

        # Change quantity of product 1
        ps1 = pedido.productos_solicitados.find_by(producto: producto1)
        ps1.update_column(:cantidad, 4)
        pedido.productos_solicitados.reload

        result = pedido.reaplicar_cupon!

        expect(result).to eq(:ok)
        pedido.productos_solicitados.reload
        # New total: 4*300 + 3*200 = 1800, discount 200 => 1600
        total_con_descuento = pedido.productos_solicitados.sum { |ps| ps.precio_con_descuento * ps.cantidad }
        expect(total_con_descuento.to_f).to be_within(0.01).of(1600.0)
      end
    end

    describe 'rounding precision' do
      it 'importe_descuento_cupon is always exact regardless of per-unit rounding' do
        # Create products that cause rounding issues: 5 extra products at $333
        (1..5).each do |i|
          prod = Productos::Producto.create!(nombre: "RoundProd#{i}", categoria: categoria, tienda: tienda)
          precio = create(:precio, producto: prod, importe: 333, fecha_desde: 1.month.ago, fecha_hasta: 1.year.from_now)
          precio.clientes << cliente
          ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: prod, cantidad: 1, precio_unitario: 333)
          ps.save(validate: false)
        end
        pedido.productos_solicitados.reload

        cupon_500 = create(:cupon, tienda: tienda, tipo_descuento: 'importe', importe: 500)
        pedido.aplicar_cupon!(cupon_500)
        pedido.flush_cache(:importe_total)

        # importe_descuento_cupon uses cupon.descuento_para directly — always exact
        expect(pedido.importe_descuento_cupon.to_f).to eq(500.0)
      end

      it 'PS-based total is within $0.01 of exact target' do
        # 33% discount on 1200 = 396
        cupon_33 = create(:cupon, :porcentaje, tienda: tienda, porcentaje: 33, limite_bonificacion: 10_000)
        pedido.aplicar_cupon!(cupon_33)
        pedido.productos_solicitados.reload

        total_sin = pedido.productos_solicitados.sum { |ps| ps.precio_unitario * ps.cantidad }
        total_con = pedido.productos_solicitados.sum { |ps| ps.precio_con_descuento * ps.cantidad }
        expected_discount = (total_sin * 33 / 100.0).round(2)
        descuento_real = (total_sin - total_con).to_f.round(2)

        expect(descuento_real).to be_within(0.01).of(expected_discount)
      end

      it 'importe_total is exactly subtotal minus discount even when per-unit price has rounding' do
        # Reproduce the real-world bug: 3 items × $9200 = $27600, 33% cupon capped at $500
        # Expected total: $27600 - $500 = $27100.00
        # Bug: distributor sets last item precio_con_descuento = floor(27100/3) = 9033.33
        #      then 9033.33 * 3 = 27099.99 (off by $0.01)
        cat = Productos::Categoria.create!(nombre: 'Cat Rounding', tienda: tienda)
        prod = Productos::Producto.create!(nombre: 'Expensive Item', categoria: cat, tienda: tienda)
        precio = create(:precio, producto: prod, importe: 9200, fecha_desde: 1.month.ago, fecha_hasta: 1.year.from_now)
        precio.clientes << cliente

        rounding_pedido = described_class.create!(
          usuario: usuario, autor: usuario, cuenta: cuenta,
          fecha: valid_fecha, tienda: tienda, estado_id: 1
        )
        ps = Productos::ProductoSolicitado.new(
          pedido: rounding_pedido, producto: prod, cantidad: 3, precio_unitario: 9200
        )
        ps.save(validate: false)
        rounding_pedido.productos_solicitados.reload

        cupon_500 = create(:cupon, :porcentaje, tienda: tienda, porcentaje: 33, limite_bonificacion: 500)
        rounding_pedido.aplicar_cupon!(cupon_500)
        rounding_pedido.flush_cache(:importe_total)

        # The exact expected total
        subtotal = 9200.0 * 3 # 27600
        discount = cupon_500.descuento_para(subtotal) # 500
        expected_total = subtotal - discount # 27100.00

        # importe_total MUST be exactly $27100.00, not $27099.99
        expect(rounding_pedido.importe_total.to_f).to eq(expected_total)
      end
    end

    describe '#crear_nc_descuento' do
      before do
        Comprobantes::Tipo.find_or_create_by(codigo: 1) do |tipo|
          tipo.desc = 'Factura'
          tipo.clase = 'Ventas::Facturacion::Factura'
          tipo.letra = 'A'
          tipo.debitan = false
        end
        Comprobantes::Tipo.find_or_create_by(codigo: 3) do |tipo|
          tipo.desc = 'Nota de Crédito'
          tipo.clase = 'Ventas::Facturacion::NotaCredito'
          tipo.letra = 'A'
          tipo.debitan = false
        end
      end

      it 'creates NC with positive discount renglones linked to factura' do
        pedido.aplicar_cupon!(cupon_importe)

        factura = Ventas::Facturacion::Factura.create!(
          tienda: tienda, pedido: pedido,
          fecha_emision: Time.current, completar_on_save: true,
          cuenta: cuenta, renglones: pedido.productos_solicitados.map do |ps|
            { producto: ps.producto, cantidad: ps.cantidad,
              descripcion: ps.producto.to_s, precio_unitario: ps.precio_unitario }
          end
        )

        pedido.crear_nc_descuento(factura)

        nc = Ventas::Facturacion::NotaCredito.last
        expect(nc).to be_present
        expect(nc.cancela_a).to eq(factura)
        # One renglon per discounted product, qty=1 each, no adjustment line
        expect(nc.renglones.count).to eq(2)
        nc.renglones.each do |r|
          expect(r.precio_unitario).to be > 0
          expect(r.cantidad).to eq(1)
          expect(r.descripcion).to include('cupón')
        end

        # NC total must exactly match the cupon discount
        nc_total = nc.renglones.sum { |r| r.precio_unitario * r.cantidad }.round(2)
        expect(nc_total).to eq(200.0)
      end

      it 'does not create NC when no discount' do
        factura = Ventas::Facturacion::Factura.create!(
          tienda: tienda, pedido: pedido,
          fecha_emision: Time.current, completar_on_save: true,
          cuenta: cuenta, renglones: pedido.productos_solicitados.map do |ps|
            { producto: ps.producto, cantidad: ps.cantidad,
              descripcion: ps.producto.to_s, precio_unitario: ps.precio_unitario }
          end
        )

        pedido.crear_nc_descuento(factura)

        expect(Ventas::Facturacion::NotaCredito.count).to eq(0)
      end
    end
  end

  describe '#medio_pago_tipo' do
    it 'defaults to nil' do
      fecha = Date.current + 1
      fecha += 1 while fecha.saturday? || fecha.sunday?
      pedido = build(:pedido, tienda: tienda, cuenta: cuenta, fecha: fecha, estado_id: 1, autor: usuario, usuario: usuario, venta_mostrador: true)
      pedido.save(validate: false)
      expect(pedido.medio_pago_tipo).to be_nil
    end

    it 'accepts valid medio types' do
      fecha = Date.current + 1
      fecha += 1 while fecha.saturday? || fecha.sunday?
      pedido = build(:pedido, tienda: tienda, cuenta: cuenta, fecha: fecha, estado_id: 1, autor: usuario, usuario: usuario, venta_mostrador: true)
      pedido.save(validate: false)

      ['efectivo', 'debito', 'credito', 'qr', 'transferencia'].each do |tipo|
        pedido.update_column(:medio_pago_tipo, tipo)
        pedido.reload
        expect(pedido.medio_pago_tipo).to eq(tipo)
      end
    end
  end

  describe '#medios_pago_cubren_total' do
    let(:categoria_mp) { create(:categoria, tienda: tienda, stock_activo: false, menu_diario: false) }
    let(:producto_mp) { create(:producto, tienda: tienda, categoria: categoria_mp) }

    def create_vm_pedido_with_products(importe:, venta_mostrador: true)
      pedido = Pedidos::Pedido.new(tienda: tienda, cuenta: cuenta, autor: usuario, usuario: usuario,
                                   estado_id: 1, fecha: Date.current, venta_mostrador: venta_mostrador)
      pedido.save(validate: false)
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto_mp,
                                             cantidad: 1, precio_unitario: importe,
                                             precio_con_descuento: importe)
      ps.save!(validate: false)
      pedido.reload
      pedido
    end

    it 'is valid when medios_pago sum matches importe_total' do
      pedido = create_vm_pedido_with_products(importe: 200.0)
      pedido.medios_pago.build(tipo: 'efectivo', importe: 200.0)
      pedido.valid?
      expect(pedido.errors[:base].select { |e| e.include?('no coincide') }).to be_empty
    end

    it 'is invalid when medios_pago sum does not match importe_total' do
      pedido = create_vm_pedido_with_products(importe: 200.0)
      pedido.medios_pago.build(tipo: 'efectivo', importe: 100.0)
      pedido.valid?
      expect(pedido.errors[:base].first).to include('no coincide')
    end

    it 'is valid with multiple medios_pago that sum to total' do
      pedido = create_vm_pedido_with_products(importe: 200.0)
      pedido.medios_pago.build(tipo: 'efectivo', importe: 100.0)
      pedido.medios_pago.build(tipo: 'qr', importe: 100.0)
      pedido.valid?
      expect(pedido.errors[:base].select { |e| e.include?('no coincide') }).to be_empty
    end

    it 'is valid when no medios_pago are present (backward compat)' do
      pedido = create_vm_pedido_with_products(importe: 200.0)
      pedido.valid?
      expect(pedido.errors[:base].select { |e| e.include?('no coincide') }).to be_empty
    end

    it 'skips validation for non-venta_mostrador pedidos' do
      pedido = create_vm_pedido_with_products(importe: 200.0, venta_mostrador: false)
      pedido.medios_pago.build(tipo: 'efectivo', importe: 50.0) # Does not match
      pedido.valid?
      expect(pedido.errors[:base].select { |e| e.include?('no coincide') }).to be_empty
    end

    it 'ignores medios_pago marked for destruction' do
      pedido = create_vm_pedido_with_products(importe: 200.0)
      pedido.medios_pago.build(tipo: 'efectivo', importe: 200.0)
      pedido.medios_pago.build(tipo: 'qr', importe: 50.0)
      pedido.medios_pago.last.mark_for_destruction
      pedido.valid?
      expect(pedido.errors[:base].select { |e| e.include?('no coincide') }).to be_empty
    end

    it 'tolerates sub-cent rounding from pesable products' do
      pedido = create_vm_pedido_with_products(importe: 0)
      # Simulate pesable: 1.5 kg * $33.33/kg = $49.995 (3 decimals)
      ps = pedido.productos_solicitados.first
      ps.update_columns(cantidad: 1, peso: 1.5, precio_unitario: 33.33,
                        precio_con_descuento: 33.33)
      pedido.reload
      # Medio matches the rounded display value ($50.00)
      pedido.medios_pago.build(tipo: 'efectivo', importe: 50.0)
      pedido.valid?
      expect(pedido.errors[:base].select { |e| e.include?('no coincide') }).to be_empty
    end
  end

  describe '#asignar_cuenta with usuario_puede_elegir_cuenta' do
    # Regression test: when the cliente has usuario_puede_elegir_cuenta enabled and
    # the user picked an alternate cuenta in the opciones page, the next save (e.g. an
    # AJAX update for turno_entrega_id) must NOT silently revert cuenta to usuario.cuenta.
    let(:multi_tienda) { Tiendas::Tienda.create!(nombre: 'Multi Cuenta Tienda', maneja_stock: false) }
    let(:multi_cliente) do
      Clientes::Cliente.create!(
        nombre: 'Cliente Multi Cuenta', cuit: '20294834487',
        dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1,
        horario_corte_pedidos: '12:00', tienda: multi_tienda,
        usuario_puede_elegir_cuenta: true
      )
    end
    let(:cuenta_default) { Clientes::Cuenta.create!(cliente: multi_cliente, nombre: 'Cuenta Default') }
    let(:cuenta_alternativa) { Clientes::Cuenta.create!(cliente: multi_cliente, nombre: 'Cuenta Alternativa') }
    let(:multi_usuario) do
      Usuarios::Usuario.create!(
        nombre: 'Multi User', login: 'multiuser',
        password: 'password123', password_confirmation: 'password123',
        email: 'multi@example.com', tipo_usuario_id: 1, dni: 11_222_333,
        cuenta: cuenta_default
      )
    end

    it 'does not revert cuenta back to usuario.cuenta on subsequent save when an alternate cuenta of the same cliente is persisted' do
      # Step 1: user finishes the opciones page choosing the alternate cuenta.
      pedido = described_class.create!(
        usuario: multi_usuario, autor: multi_usuario, cuenta: cuenta_default,
        fecha: valid_fecha, estado_id: 1, tienda: multi_tienda
      )
      pedido.enviar_a_id = cuenta_alternativa.id
      pedido.save!
      expect(pedido.reload.cuenta_id).to eq(cuenta_alternativa.id)

      # Step 2: a later request (e.g. AJAX PATCH for turno) reloads the pedido and
      # saves it again. The @asigno_cuenta_manual flag is gone — the bug is that
      # asignar_cuenta resets cuenta back to usuario.cuenta (cuenta_default).
      reloaded = described_class.find(pedido.id)
      reloaded.save!

      expect(reloaded.reload.cuenta_id).to eq(cuenta_alternativa.id)
    end

    it 'overrides cuenta with usuario.cuenta when cuenta belongs to a different cliente' do
      otro_cliente = Clientes::Cliente.create!(
        nombre: 'Otro Cliente', cuit: '20294834487',
        dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1,
        horario_corte_pedidos: '12:00', tienda: multi_tienda
      )
      cuenta_otro_cliente = Clientes::Cuenta.create!(cliente: otro_cliente, nombre: 'Cuenta Otro')

      pedido = described_class.new(
        usuario: multi_usuario, autor: multi_usuario, cuenta: cuenta_otro_cliente,
        fecha: valid_fecha, estado_id: 1, tienda: multi_tienda
      )

      expect { pedido.valid? }.not_to raise_error
      expect(pedido.cuenta_id).to eq(multi_usuario.cuenta_id)
    end
  end

  describe '#verificar_local' do
    # Regression: cambiar_cuenta creates a sibling pendiente pedido without a local
    # for multiple-locales tiendas. verificar_local must skip for pendiente pedidos
    # (consistent with all other draft-cart validation guards).
    let(:ml_tienda) do
      Tiendas::Tienda.create!(nombre: 'ML Tienda', maneja_stock: false, multiple_locales: true)
    end
    let(:ml_local) do
      Locales::Local.create!(nombre: 'Local A', tienda: ml_tienda,
                             domicilio: 'Calle A 1', telefono: '000')
    end
    let(:ml_admin) do
      Usuarios::Usuario.create!(nombre: 'ML Admin', login: 'ml_admin_vl',
                                password: 'password123', password_confirmation: 'password123',
                                email: 'ml_admin_vl@example.com', tipo_usuario_id: 2,
                                dni: 44_111_222).tap { |u| u.tiendas << ml_tienda }
    end
    let(:ml_cliente) do
      Clientes::Cliente.create!(nombre: 'ML Cliente', cuit: '20294834487',
                                dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1,
                                horario_corte_pedidos: '12:00', tienda: ml_tienda)
    end
    let(:ml_cuenta) { Clientes::Cuenta.create!(cliente: ml_cliente, nombre: 'Cuenta ML') }

    before { ml_admin.update_column(:visualizando_tienda_id, ml_tienda.id) }

    it 'is valid for a pendiente pedido even when local is blank (draft cart)' do
      p = Pedidos::Pedido.new(
        tienda: ml_tienda, autor: ml_admin, cuenta: ml_cuenta,
        estado_id: 1, fecha: nil, local: nil
      )
      p.valid?
      expect(p.errors[:local]).to be_empty
    end

    it 'is invalid for a non-pendiente pedido when local is blank' do
      fecha = Date.current + 1
      fecha += 1 while fecha.saturday? || fecha.sunday?
      allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante).and_return(true)

      p = Pedidos::Pedido.new(
        tienda: ml_tienda, autor: ml_admin, cuenta: ml_cuenta,
        estado_id: 2, fecha: fecha, local: nil, no_validar_fecha: true
      )
      p.valid?
      expect(p.errors[:local]).to include('Debe tener local de venta')
    end

    it 'is valid for a non-pendiente pedido when local is set' do
      fecha = Date.current + 1
      fecha += 1 while fecha.saturday? || fecha.sunday?
      allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante).and_return(true)

      p = Pedidos::Pedido.new(
        tienda: ml_tienda, autor: ml_admin, cuenta: ml_cuenta,
        estado_id: 2, fecha: fecha, local: ml_local, no_validar_fecha: true
      )
      p.valid?
      expect(p.errors[:local]).to be_empty
    end
  end

  describe '#fecha_valida' do
    # Regression: cambiar_cuenta creates a sibling pendiente pedido with a past fecha
    # via no_validar_fecha: true. fecha_valida must still fire for non-pendiente pedidos
    # but must be suppressible via no_validar_fecha for the sibling-create path.
    let(:fv_tienda) { create(:tienda) }
    let(:fv_cliente) { create(:cliente, tienda: fv_tienda) }
    let(:fv_cuenta) { create(:cuenta, cliente: fv_cliente) }
    let(:fv_usuario) do
      create(:usuario, :admin).tap do |u|
        u.tiendas << fv_tienda
        u.update_column(:visualizando_tienda_id, fv_tienda.id)
      end
    end

    it 'is valid with a past fecha when no_validar_fecha is true (legacy escape hatch, e.g. confirmar!, cancelar!)' do
      past_date = Date.current - 5
      p = Pedidos::Pedido.new(
        tienda: fv_tienda, autor: fv_usuario, usuario: fv_usuario, cuenta: fv_cuenta,
        estado_id: 1, fecha: past_date, local: nil, no_validar_fecha: true
      )
      p.valid?
      expect(p.errors[:fecha]).not_to include(a_string_starting_with('inválida'))
    end

    it 'is invalid for a non-pendiente pedido when fecha is in the past' do
      past_date = Date.current - 5
      allow_any_instance_of(Pedidos::Pedido).to receive(:crear_comprobante).and_return(true)
      p = Pedidos::Pedido.new(
        tienda: fv_tienda, autor: fv_usuario, usuario: fv_usuario, cuenta: fv_cuenta,
        estado_id: 2, fecha: past_date, local: nil
      )
      # Stub fecha_permitida? to return false regardless of user type so the
      # validation fires independently of business-day rules.
      allow(p).to receive(:fecha_permitida?).and_return(false)
      p.valid?
      expect(p.errors[:fecha]).to include(a_string_starting_with('inválida'))
    end
  end

  # Bug A: asignar_tienda used the legacy `cliente.tienda` shim (returns
  # `tiendas.first`) which mis-tagged pedidos for shared HABTM clientes. It
  # should derive from the author's active tienda when available.
  describe '#asignar_tienda (Bug A)' do
    let(:tienda_a) { Tiendas::Tienda.create!(nombre: 'AT Tienda A') }
    let(:tienda_b) { Tiendas::Tienda.create!(nombre: 'AT Tienda B') }
    let(:cliente_shared) do
      Clientes::Cliente.create!(
        nombre: 'AT Shared',
        cuit: '20294834487',
        dia_inicio_ciclo_facturacion: 1,
        vencimiento_a: 1,
        horario_corte_pedidos: '12:00',
        tiendas: [tienda_a, tienda_b]
      )
    end
    let(:cuenta_shared) { Clientes::Cuenta.create!(cliente: cliente_shared, nombre: 'AT Cta') }
    let(:usuario_b) do
      u = Usuarios::Usuario.create!(
        nombre: 'AT Usu B', login: 'atusub', password: 'password123',
        password_confirmation: 'password123', email: 'atb@example.com',
        tipo_usuario_id: 1, dni: 22_222_222, cuenta: cuenta_shared
      )
      u.update_column(:visualizando_tienda_id, tienda_b.id)
      u
    end

    it 'uses the autor active tienda for a shared HABTM cliente' do
      p = described_class.new(usuario: usuario_b, autor: usuario_b, cuenta: cuenta_shared,
                              fecha: valid_fecha, estado_id: 1)
      p.send(:asignar_tienda)
      expect(p.tienda).to eq(tienda_b)
    end
  end

  # Bug C: aceptar! lacked the idempotency guard that confirmar! has, so a
  # double-submit (form retry, racing webhook + cron, etc.) re-ran the
  # crear_comprobante callback and could create a second factura before the
  # first one was committed. aceptar! must short-circuit if the pedido is
  # already in estado 2 or later.
  describe '#aceptar! idempotency (Bug C)' do
    let(:c_tienda) { Tiendas::Tienda.create!(nombre: 'Idem Tienda') }
    let(:c_cliente) do
      Clientes::Cliente.create!(nombre: 'Idem Cliente', cuit: '20294834487',
                                dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1,
                                horario_corte_pedidos: '12:00', tienda: c_tienda)
    end
    let(:c_cuenta) { Clientes::Cuenta.create!(cliente: c_cliente, nombre: 'Idem Cta') }
    let(:c_usuario) do
      Usuarios::Usuario.create!(nombre: 'Idem Usu', login: 'idemusu', password: 'password123',
                                password_confirmation: 'password123', email: 'idem@example.com',
                                tipo_usuario_id: 1, dni: 33_333_333, cuenta: c_cuenta)
    end

    it 'is a no-op when called on an already-aceptado pedido' do
      p = described_class.new(usuario: c_usuario, autor: c_usuario, cuenta: c_cuenta,
                              fecha: valid_fecha, estado_id: 1, tienda: c_tienda)
      p.asignar_cuenta_manual
      p.cuenta = c_cuenta
      p.save!
      p.update_column(:estado_id, 2)
      p.reload

      expect(p).not_to receive(:save!)
      expect(p.aceptar!(c_usuario)).to be_truthy
      expect(p.reload.estado_id).to eq(2)
    end
  end

  # Bug E: crear_factura used Factura.create (non-bang), silently swallowing
  # validation failures. The pedido would then go to estado aceptado without a
  # comprobante, and the missing factura only surfaced much later as ledger
  # drift. Switching to create! makes the surrounding transaction roll back.
  describe '#crear_factura validation rollback (Bug E)' do
    let(:e_tienda) { Tiendas::Tienda.create!(nombre: 'Bug E Tienda') }
    let(:e_cliente) do
      Clientes::Cliente.create!(nombre: 'Bug E Cliente', cuit: '20294834487',
                                dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1,
                                horario_corte_pedidos: '12:00', tienda: e_tienda)
    end
    let(:e_cuenta) { Clientes::Cuenta.create!(cliente: e_cliente, nombre: 'Bug E Cta') }
    let(:e_usuario) do
      Usuarios::Usuario.create!(nombre: 'Bug E Usu', login: 'bugeusu', password: 'password123',
                                password_confirmation: 'password123', email: 'buge@example.com',
                                tipo_usuario_id: 1, dni: 44_444_444, cuenta: e_cuenta)
    end

    it 'raises ActiveRecord::RecordInvalid when factura is invalid' do
      p = described_class.new(usuario: e_usuario, autor: e_usuario, cuenta: e_cuenta,
                              fecha: valid_fecha, estado_id: 1, tienda: e_tienda)
      p.asignar_cuenta_manual
      p.cuenta = e_cuenta
      p.save!

      invalid_factura = Ventas::Facturacion::Factura.new
      invalid_factura.errors.add(:base, 'forced for test')
      allow(Ventas::Facturacion::Factura).to receive(:create!)
        .and_raise(ActiveRecord::RecordInvalid.new(invalid_factura))
      # Bug E: if the code still uses non-bang .create, this stub returns
      # an invalid (unsaved) record silently and the test fails.
      allow(Ventas::Facturacion::Factura).to receive(:create).and_return(invalid_factura)

      expect { p.crear_factura(e_usuario) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  # Bug D pedido-side: anular_factura must not create another NC when the
  # factura is already fully credited. Otherwise a retry / double-call leaves
  # the ledger gap > total.
  describe '#anular_factura already-credited guard (Bug D)' do
    let(:d_factura) do
      f = double('Factura').as_null_object
      allow(f).to receive_messages(total: 100.0)
      allow(f).to receive(:with_lock).and_yield
      f
    end

    def reloadable(arr)
      arr.define_singleton_method(:reload) { self }
      arr
    end

    it 'returns early without generating a new NC when ya_creditado >= total' do
      nc_existing = double('NC')
      allow(nc_existing).to receive_messages(is_a?: true, confirmado?: true, total: 100.0)
      allow(nc_existing).to receive(:is_a?).with(Ventas::Facturacion::NotaCredito).and_return(true)
      allow(d_factura).to receive(:afectadores).and_return(reloadable([nc_existing]))

      p = described_class.new
      expect(Ventas::Facturacion::NotaCredito).not_to receive(:generar_nc_pedido)
      p.anular_factura(nil, d_factura)
    end

    it 'proceeds when no NC has been credited yet' do
      allow(d_factura).to receive(:afectadores).and_return(reloadable([]))
      # Stub a pedido NC return so generar_nc_pedido path is exercised but
      # the save chain is skipped (nc is nil → falls through to error path
      # which we also stub).
      allow(Ventas::Facturacion::NotaCredito).to receive(:generar_nc_pedido).and_return(nil)
      p = described_class.new
      allow(p).to receive(:error_al_generar_nc_para_pedido)
      expect(Ventas::Facturacion::NotaCredito).to receive(:generar_nc_pedido).with(d_factura)
      p.anular_factura(nil, d_factura)
    end
  end

  # Bug F (production exception 2026-05-21): re-confirming a venta_mostrador
  # pedido that was originally confirmed with a descuento_venta_mostrador (or
  # cupon) leaves a partial confirmed NC against the original factura. When
  # anular_factura then generates a full-amount cancelation NC, the cumulative
  # NC total exceeds the factura and no_excede_total_factura raises:
  #   "El total de notas de crédito ($3600.00) excede el total de la factura ($3000.00)"
  # Fix: scale the cancelation NC renglones to neto = (total_factura - ya_creditado).
  describe '#anular_factura with partial discount NC already credited (Bug F)' do
    before do
      Comprobantes::Tipo.find_or_create_by(codigo: 1) do |tipo|
        tipo.desc = 'Factura'
        tipo.clase = 'Ventas::Facturacion::Factura'
        tipo.letra = 'A'
        tipo.debitan = false
      end
      Comprobantes::Tipo.find_or_create_by(codigo: 3) do |tipo|
        tipo.desc = 'Nota de Crédito'
        tipo.clase = 'Ventas::Facturacion::NotaCredito'
        tipo.letra = 'A'
        tipo.debitan = false
      end
    end

    let(:bug_f_categoria) { Productos::Categoria.create!(nombre: 'Cat Bug F', tienda: tienda, stock_activo: false) }
    let(:bug_f_producto) do
      Productos::Producto.create!(nombre: 'Prod Bug F', categoria: bug_f_categoria, tienda: tienda)
    end

    let(:bug_f_pedido) do
      p = described_class.new(tienda: tienda, cuenta: cuenta, autor: usuario, usuario: usuario,
                              fecha: valid_fecha, estado_id: 1, venta_mostrador: true)
      p.save!(validate: false)
      p
    end

    let(:bug_f_factura) do
      Ventas::Facturacion::Factura.create!(
        tienda: tienda, cuenta: cuenta, autor: usuario, pedido: bug_f_pedido,
        fecha_emision: Time.current, completar_on_save: true,
        renglones: [{ producto: bug_f_producto, cantidad: 1,
                      descripcion: bug_f_producto.to_s, precio_unitario: 3000 }]
      )
    end

    def confirm_discount_nc!(factura, descuento_amount)
      nc = Ventas::Facturacion::NotaCredito.new
      nc.preparar_para_cancelar_a(
        factura,
        [Ventas::Facturacion::Renglon.new(producto: bug_f_producto, cantidad: 1,
                                          precio_unitario: descuento_amount,
                                          descripcion: 'Descuento previo')],
        factura
      )
      nc.completar_on_save = true
      nc.save!
      nc.confirmar(usuario).save!
      nc
    end

    it 'does not raise no_excede_total_factura when a partial discount NC exists' do
      factura = bug_f_factura
      confirm_discount_nc!(factura, 600) # discount NC for $600 against $3000 factura

      expect { bug_f_pedido.anular_factura(usuario, factura) }.not_to raise_error
    end

    it 'creates a cancelation NC scaled to the uncredited remainder' do
      factura = bug_f_factura
      discount_nc = confirm_discount_nc!(factura, 600)

      bug_f_pedido.anular_factura(usuario, factura)

      confirmed_state = Comprobantes::Estado[:confirmado].id
      ncs = Ventas::Facturacion::NotaCredito
            .joins(:afectaciones)
            .where(afectaciones: { afectado_id: factura.id }, estado_id: confirmed_state)
            .distinct
            .to_a
      cancelation_nc = ncs.reject { |nc| nc.id == discount_nc.id }.last
      expect(cancelation_nc).to be_present
      expect(cancelation_nc.total.to_f).to be_within(0.02).of(2400.0) # 3000 - 600
      total_credited = ncs.sum { |nc| nc.total.to_f.abs }
      expect(total_credited).to be_within(0.02).of(3000.0)
    end

    it 'creates a full-amount NC when no partial credit exists' do
      factura = bug_f_factura

      bug_f_pedido.anular_factura(usuario, factura)

      ncs = Ventas::Facturacion::NotaCredito
            .joins(:afectaciones)
            .where(afectaciones: { afectado_id: factura.id },
                   estado_id: Comprobantes::Estado[:confirmado].id)
      expect(ncs.count).to eq(1)
      expect(ncs.first.total.to_f).to be_within(0.02).of(3000.0)
    end
  end

  describe '#prevenir_destruccion_si_pago_o_facturado' do
    let(:base_pedido) do
      p = described_class.new(tienda: tienda, cuenta: cuenta, autor: usuario,
                              usuario: usuario, fecha: valid_fecha, estado_id: 1)
      p.save!(validate: false)
      p
    end

    it 'allows destroy when pedido is pendiente (estado 1)' do
      pedido = base_pedido
      expect { pedido.destroy! }.not_to raise_error
      expect(described_class.where(id: pedido.id)).to be_empty
    end

    it 'allows destroy when pedido is aceptado/facturado but NOT cobrado (NC flow)' do
      pedido = base_pedido
      pedido.update_columns(estado_id: 2, facturado: true, cobrado: false)
      expect { pedido.destroy! }.not_to raise_error
    end

    it 'blocks destroy when pedido is cobrado' do
      pedido = base_pedido
      pedido.update_columns(cobrado: true)
      expect { pedido.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
      expect(described_class.exists?(pedido.id)).to be(true)
    end

    it 'blocks destroy when pedido has pagos_electronicos' do
      pedido = base_pedido
      Ventas::Facturacion::PagoElectronico.create!(
        pedido: pedido, pago_id: 12_345, transaction_amount: 100,
        status: 'approved', currency_id: 'ARS'
      )
      expect { pedido.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
      expect(described_class.exists?(pedido.id)).to be(true)
    end

    it 'bypasses the guard when forzar_destruccion is set' do
      pedido = base_pedido
      pedido.update_columns(cobrado: true, estado_id: 3)
      pedido.forzar_destruccion = true
      expect { pedido.destroy! }.not_to raise_error
    end
  end

  describe '#pedido_multiple_owner_matches' do
    let(:otro_usuario) do
      Usuarios::Usuario.create!(
        nombre: 'Otro Match', login: 'otromatch',
        password: 'password123', password_confirmation: 'password123',
        email: 'otromatch@example.com', tipo_usuario_id: 1, dni: 99_000_011,
        cuenta: cuenta, tienda_cliente: tienda
      )
    end

    it 'rejects linking when the group is owned by a different user' do
      grupo = Pedidos::PedidoMultiple.create!(usuario: otro_usuario)
      pedido = described_class.new(
        tienda: tienda, cuenta: cuenta, autor: usuario, usuario: usuario,
        fecha: valid_fecha, estado_id: 1, pedido_multiple_id: grupo.id
      )
      expect(pedido).not_to be_valid
      expect(pedido.errors[:pedido_multiple_id]).to include('no pertenece a este usuario')
    end

    it 'accepts linking when autor matches the group owner (admin authoring for employee)' do
      grupo = Pedidos::PedidoMultiple.create!(usuario: usuario)
      pedido = described_class.new(
        tienda: tienda, cuenta: cuenta, autor: usuario, usuario: otro_usuario,
        fecha: valid_fecha, estado_id: 1, pedido_multiple_id: grupo.id
      )
      expect(pedido).to be_valid
    end

    it 'accepts linking when usuario matches the group owner' do
      grupo = Pedidos::PedidoMultiple.create!(usuario: usuario)
      pedido = described_class.new(
        tienda: tienda, cuenta: cuenta, autor: otro_usuario, usuario: usuario,
        fecha: valid_fecha, estado_id: 1, pedido_multiple_id: grupo.id
      )
      expect(pedido).to be_valid
    end

    it 'accepts linking into a cuenta-only group when cuenta matches' do
      bucket = Pedidos::PedidoMultiple.create!(cuenta: cuenta)
      pedido = described_class.new(
        tienda: tienda, cuenta: cuenta, autor: otro_usuario, usuario: otro_usuario,
        fecha: valid_fecha, estado_id: 1, pedido_multiple_id: bucket.id
      )
      expect(pedido).to be_valid
    end

    it 'rejects linking into a cuenta-only group when cuenta differs' do
      otra_cuenta = Clientes::Cuenta.create!(cliente: cliente, nombre: 'Otra Cuenta')
      bucket = Pedidos::PedidoMultiple.create!(cuenta: otra_cuenta)
      pedido = described_class.new(
        tienda: tienda, cuenta: cuenta, autor: usuario, usuario: usuario,
        fecha: valid_fecha, estado_id: 1, pedido_multiple_id: bucket.id
      )
      expect(pedido).not_to be_valid
      expect(pedido.errors[:pedido_multiple_id]).to include('no pertenece a este usuario')
    end
  end

  describe '#imputar_pago with missing user in external_reference' do
    it 'does not raise NoMethodError when user id is unknown' do
      pedido.save!
      response = {
        'external_reference' => "#{pedido.id}-99999999",
        'id' => 1, 'order' => { 'id' => 2 }
      }
      expect { pedido.imputar_pago(response) }.not_to raise_error
      expect(pedido.reload.cobrado).to be false
    end

    it 'does not raise when pedido is already confirmed and has no local on multiple_locales tienda' do
      tienda.update!(multiple_locales: true)
      local = Locales::Local.create!(nombre: 'L1', tienda: tienda, domicilio: 'D 1', telefono: '111')
      tienda.update!(local_atencion_carrito_id: local.id)
      pedido.save!
      categoria = Productos::Categoria.create!(nombre: 'Cat IP', tienda: tienda, stock_activo: false, menu_diario: false)
      producto = Productos::Producto.create!(nombre: 'P IP', codigo: 'PIP1', tienda: tienda, categoria: categoria)
      precio = Productos::Precio.create!(producto: producto, importe: 100.0, fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
      precio.clientes << cliente unless precio.clientes.include?(cliente)
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 1, precio_unitario: 100.0)
      ps.save(validate: false)
      pedido.update_columns(estado_id: 3, local_id: nil, facturado: false)
      response = {
        'external_reference' => "#{pedido.id}-#{usuario.id}",
        'id' => 1, 'order' => { 'id' => 2 },
        'date_created' => Time.current, 'date_approved' => Time.current,
        'date_last_updated' => Time.current, 'money_release_date' => Time.current,
        'payment_method_id' => 'visa', 'payment_type_id' => 'credit_card',
        'status' => 'approved', 'status_detail' => 'accredited',
        'currency_id' => 'ARS', 'description' => '', 'collector_id' => 1,
        'installments' => 1, 'transaction_amount' => 100,
        'transaction_amount_refunded' => 0, 'coupon_amount' => 0,
        'transaction_details' => {
          'total_paid_amount' => 100, 'overpaid_amount' => 0,
          'net_received_amount' => 100, 'installment_amount' => 100
        }
      }
      expect { pedido.imputar_pago(response) }.not_to raise_error
      expect(pedido.reload.local_id).to eq(local.id)
    end
  end
end
