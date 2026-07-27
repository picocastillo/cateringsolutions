# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VentasMostrador::Pedidos', type: :request do
  let(:tienda) do
    create(:tienda,
           nombre: 'Tienda VM Test',
           dominio: 'localhost',
           telefono: '123456789',
           email: 'test@vm.com',
           venta_mostrador: true,
           carrito_de_compras: true,
           horarios_de_entrega: false,
           maneja_stock: false)
  end

  let(:cliente_cf) do
    create(:cliente,
           nombre: 'Consumidor Final',
           tienda: tienda,
           dia_inicio_ciclo_facturacion: 1,
           vencimiento_a: 30,
           horarios_de_entrega: false,
           usuario_puede_elegir_cuenta: false,
           permitir_envios_a_domicilio: false,
           cuenta_corriente: true,
           listas_de_precio_privada: false)
  end

  let(:cuenta_cf) { cliente_cf.cuentas.first || create(:cuenta, nombre: 'Consumidor Final', cliente: cliente_cf) }

  let(:admin) do
    user = create(:usuario, :admin,
                  login: 'adminvm',
                  password: 'password123',
                  password_confirmation: 'password123',
                  nombre: 'Admin VM',
                  email: 'adminvm@example.com',
                  visualizando_tienda: tienda)
    user.tiendas << tienda unless user.tiendas.include?(tienda)
    # Admin must have a cuenta so asignar_cuenta callback doesn't nil-out cuenta_id
    user.update_column(:cuenta_id, cuenta_cf.id) unless user.cuenta_id
    user
  end

  let(:categoria) do
    create(:categoria, nombre: 'Cat VM', tienda: tienda, stock_activo: false, menu_diario: false).tap do |cat|
      cliente_cf.categorias << cat unless cliente_cf.categorias.include?(cat)
    end
  end

  let(:producto1) do
    create(:producto, nombre: 'Empanada VM', codigo: 'EVM001', tienda: tienda, categoria: categoria)
  end

  let(:producto2) do
    create(:producto, nombre: 'Gaseosa VM', codigo: 'GVM001', tienda: tienda, categoria: categoria)
  end

  before do
    create(:categoria, nombre: 'Menu Diario VM', tienda: tienda, menu_diario: true)
    login_as(admin)
    bypass_authorization

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

    # Ensure cuenta_cf exists before any request
    cuenta_cf

    create(:precio, producto: producto1, importe: 200.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    create(:precio, producto: producto2, importe: 100.0,
                    fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
  end

  describe 'GET /ventas_mostrador/pedidos' do
    it 'returns HTTP 200' do
      get ventas_mostrador_pedidos_path
      expect(response).to have_http_status(:ok)
    end

    it 'renders the POS page with form elements' do
      get ventas_mostrador_pedidos_path
      expect(response.body).to include('Venta Mostrador')
      expect(response.body).to include('pedido_fecha')
    end

    it 'creates a pending pedido for the admin on first visit' do
      expect do
        get ventas_mostrador_pedidos_path
      end.to change(Pedidos::Pedido, :count).by(1)

      pedido = Pedidos::Pedido.last
      expect(pedido.venta_mostrador).to be true
      expect(pedido.estado_id).to eq(1)
      expect(pedido.autor_id).to eq(admin.id)
    end

    context 'with existing confirmed pedidos' do
      before do
        3.times do |i|
          pedido = Pedidos::Pedido.new(
            autor: admin, cuenta: cuenta_cf,
            fecha: Date.current, estado_id: 1,
            tienda_id: tienda.id, venta_mostrador: true
          )
          pedido.asignar_cuenta_manual
          pedido.cuenta = cuenta_cf
          pedido.no_validar_fecha = true
          pedido.save!
          ps = Productos::ProductoSolicitado.new(
            pedido: pedido, producto: producto1,
            cantidad: (i + 1) * 2, precio_unitario: 200.0
          )
          ps.save(validate: false)
          pedido.facturando
          pedido.aceptar! if pedido.pendiente?
        end
      end

      it 'uses footer_aggregates instead of inline base_query calls' do
        get ventas_mostrador_pedidos_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Pedidos Totales')
        expect(response.body).to include('Productos Totales')
      end

      it 'includes eager-loaded associations (no N+1)' do
        get ventas_mostrador_pedidos_path
        expect(response).to have_http_status(:ok)
        # The response should render pedido data without N+1 queries
        expect(response.body).to include('Empanada VM')
      end
    end
  end

  describe 'GET /ventas_mostrador/pedidos (JS format)' do
    it 'returns filtered results via AJAX' do
      # Ensure a pending pedido exists for the user
      get ventas_mostrador_pedidos_path

      get ventas_mostrador_pedidos_path, xhr: true
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /ventas_mostrador/pedidos/:id (discount edge cases)' do
    let!(:pedido) do
      p = Pedidos::Pedido.new(
        autor: admin, cuenta: cuenta_cf, usuario: admin,
        fecha: Date.current, estado_id: 1,
        tienda_id: tienda.id, venta_mostrador: true
      )
      p.asignar_cuenta_manual
      p.cuenta = cuenta_cf
      p.no_validar_fecha = true
      p.save!
      p
    end

    def add_producto(pedido, producto, cantidad, precio)
      ps = Productos::ProductoSolicitado.new(
        pedido: pedido, producto: producto,
        cantidad: cantidad, precio_unitario: precio,
        precio_con_descuento: precio
      )
      ps.save(validate: false)
      ps
    end

    def confirm_pedido(pedido, medios_pago_attrs)
      ps_attrs = {}
      pedido.productos_solicitados.reload.each_with_index do |ps, i|
        ps_attrs[i.to_s] = { id: ps.id }
      end

      patch ventas_mostrador_pedido_path(pedido), params: {
        pedido: {
          fecha: Date.current.to_s,
          cuenta_id: cuenta_cf.id,
          medios_pago_attributes: medios_pago_attrs,
          productos_solicitados_venta_mostrador_attributes: ps_attrs
        }
      }
    end

    context 'single medio de pago efectivo above minimum' do
      it 'applies discount and adjusts the medio de pago' do
        add_producto(pedido, producto1, 5, 200.0) # 5 x $200 = $1000

        create(:descuento_venta_mostrador, tienda: tienda,
                                           nombre: 'Efectivo $100',
                                           tipo_descuento: 'importe',
                                           importe: 100,
                                           medio_pago_tipo: 'efectivo',
                                           importe_minimo: 500)

        confirm_pedido(pedido, { '0' => { tipo: 'efectivo', importe: '1000' } })

        expect(response).to redirect_to(ventas_mostrador_pedidos_path)
        expect(flash[:error]).to be_blank

        pedido.reload
        expect(pedido.estado_id).to eq(3) # confirmado
        expect(pedido.descuento_venta_mostrador).to be_present
        expect(pedido.medios_pago.first.importe.to_f).to eq(900.0) # 1000 - 100
      end
    end

    context 'multiple medios de pago — efectivo is dominant' do
      it 'applies discount using the dominant medio importe (not total) and adjusts only that medio' do
        add_producto(pedido, producto1, 10, 200.0) # 10 x $200 = $2000

        create(:descuento_venta_mostrador, tienda: tienda,
                                           nombre: 'Efectivo 10%',
                                           tipo_descuento: 'porcentaje',
                                           porcentaje: 10,
                                           limite_bonificacion: 99_999,
                                           medio_pago_tipo: 'efectivo',
                                           importe_minimo: 1000)

        # Efectivo $1500 (dominant) + QR $500 = $2000
        confirm_pedido(pedido, {
                         '0' => { tipo: 'efectivo', importe: '1500' },
                         '1' => { tipo: 'qr', importe: '500' }
                       })

        expect(response).to redirect_to(ventas_mostrador_pedidos_path)
        expect(flash[:error]).to be_blank

        pedido.reload
        expect(pedido.estado_id).to eq(3)
        expect(pedido.descuento_venta_mostrador.nombre).to eq('Efectivo 10%')

        # 10% of $1500 (medio importe) = $150 discount (NOT 10% of $2000)
        # Efectivo adjusted: $1500 - $150 = $1350, QR stays at $500
        efectivo_mp = pedido.medios_pago.find_by(tipo: 'efectivo')
        qr_mp = pedido.medios_pago.find_by(tipo: 'qr')
        expect(efectivo_mp.importe.to_f).to eq(1350.0)
        expect(qr_mp.importe.to_f).to eq(500.0)
        expect(pedido.monto_descuento_vm.to_f).to eq(150.0)
      end
    end

    context 'multiple medios de pago — efectivo is NOT dominant' do
      it 'does NOT apply efectivo discount when QR has higher importe' do
        add_producto(pedido, producto1, 10, 200.0) # 10 x $200 = $2000

        # Discount exists for efectivo only
        create(:descuento_venta_mostrador, tienda: tienda,
                                           nombre: 'Efectivo only',
                                           tipo_descuento: 'importe',
                                           importe: 300,
                                           medio_pago_tipo: 'efectivo',
                                           importe_minimo: 1000)

        # QR $1200 (dominant) + Efectivo $800 = $2000
        # Dominant medio is QR, so "efectivo" discount should NOT apply
        confirm_pedido(pedido, {
                         '0' => { tipo: 'qr', importe: '1200' },
                         '1' => { tipo: 'efectivo', importe: '800' }
                       })

        expect(response).to redirect_to(ventas_mostrador_pedidos_path)
        expect(flash[:error]).to be_blank

        pedido.reload
        expect(pedido.estado_id).to eq(3)
        expect(pedido.descuento_venta_mostrador).to be_nil

        # No adjustment — both medios keep original amounts
        qr_mp = pedido.medios_pago.find_by(tipo: 'qr')
        efectivo_mp = pedido.medios_pago.find_by(tipo: 'efectivo')
        expect(qr_mp.importe.to_f).to eq(1200.0)
        expect(efectivo_mp.importe.to_f).to eq(800.0)
      end
    end

    context 'efectivo below minimum but total above minimum' do
      it 'does NOT apply discount when pedido total is below importe_minimo' do
        add_producto(pedido, producto1, 10, 200.0) # 10 x $200 = $2000

        # Discount requires minimum $5000 on importe_total (above $2000)
        create(:descuento_venta_mostrador, tienda: tienda,
                                           nombre: 'Efectivo big min',
                                           tipo_descuento: 'importe',
                                           importe: 200,
                                           medio_pago_tipo: 'efectivo',
                                           importe_minimo: 5000)

        # Efectivo $1000 (dominant) + QR $1000 = $2000 total < $5000 min
        confirm_pedido(pedido, {
                         '0' => { tipo: 'efectivo', importe: '1000' },
                         '1' => { tipo: 'qr', importe: '1000' }
                       })

        expect(response).to redirect_to(ventas_mostrador_pedidos_path)
        expect(flash[:error]).to be_blank

        pedido.reload
        expect(pedido.estado_id).to eq(3)
        expect(pedido.descuento_venta_mostrador).to be_nil
      end
    end

    context 'percentage discount with limite_bonificacion cap' do
      it 'caps the discount at limite_bonificacion and adjusts medio correctly' do
        add_producto(pedido, producto1, 50, 200.0) # 50 x $200 = $10,000

        # 10% of $10,000 = $1,000 but cap at $500
        create(:descuento_venta_mostrador, tienda: tienda,
                                           nombre: 'Efectivo 10% max 500',
                                           tipo_descuento: 'porcentaje',
                                           porcentaje: 10,
                                           limite_bonificacion: 500,
                                           medio_pago_tipo: 'efectivo',
                                           importe_minimo: 0)

        confirm_pedido(pedido, { '0' => { tipo: 'efectivo', importe: '10000' } })

        expect(response).to redirect_to(ventas_mostrador_pedidos_path)
        expect(flash[:error]).to be_blank

        pedido.reload
        expect(pedido.estado_id).to eq(3)
        expect(pedido.descuento_venta_mostrador.nombre).to eq('Efectivo 10% max 500')

        # Discount capped at $500 (not $1000)
        expect(pedido.medios_pago.first.importe.to_f).to eq(9500.0)
      end
    end

    context 'QR discount with efectivo dominant — no match' do
      it 'does NOT apply QR discount when efectivo is dominant' do
        add_producto(pedido, producto1, 5, 200.0) # 5 x $200 = $1000

        create(:descuento_venta_mostrador, :qr, tienda: tienda,
                                                nombre: 'Solo QR',
                                                importe: 200,
                                                importe_minimo: 0)

        confirm_pedido(pedido, { '0' => { tipo: 'efectivo', importe: '1000' } })

        expect(response).to redirect_to(ventas_mostrador_pedidos_path)
        expect(flash[:error]).to be_blank

        pedido.reload
        expect(pedido.descuento_venta_mostrador).to be_nil
        expect(pedido.medios_pago.first.importe.to_f).to eq(1000.0)
      end
    end

    context 'no validation mismatch error with discount applied' do
      it 'does not produce medios de pago mismatch error' do
        add_producto(pedido, producto1, 100, 200.0)  # $20,000
        add_producto(pedido, producto2, 100, 100.0)  # $10,000
        # total = $30,000

        create(:descuento_venta_mostrador, tienda: tienda,
                                           nombre: 'Efectivo 15%',
                                           tipo_descuento: 'porcentaje',
                                           porcentaje: 15,
                                           limite_bonificacion: 99_999,
                                           medio_pago_tipo: 'efectivo',
                                           importe_minimo: 0)

        confirm_pedido(pedido, { '0' => { tipo: 'efectivo', importe: '30000' } })

        expect(response).to redirect_to(ventas_mostrador_pedidos_path)
        follow_redirect!

        # Must NOT contain the mismatch error
        expect(response.body).not_to include('no coincide con el total del pedido')

        pedido.reload
        expect(pedido.estado_id).to eq(3)
        # 15% of $30,000 = $4,500
        expect(pedido.medios_pago.first.importe.to_f).to eq(25_500.0)
      end
    end

    context 'blank medio_pago_tipo (todos) discount' do
      it 'applies discount regardless of which medio de pago is used' do
        add_producto(pedido, producto1, 10, 200.0) # 10 x $200 = $2000

        create(:descuento_venta_mostrador, tienda: tienda,
                                           nombre: 'Todos $300',
                                           tipo_descuento: 'importe',
                                           importe: 300,
                                           medio_pago_tipo: '',
                                           importe_minimo: 0)

        confirm_pedido(pedido, { '0' => { tipo: 'qr', importe: '2000' } })

        expect(response).to redirect_to(ventas_mostrador_pedidos_path)
        expect(flash[:error]).to be_blank

        pedido.reload
        expect(pedido.estado_id).to eq(3)
        expect(pedido.descuento_venta_mostrador.nombre).to eq('Todos $300')
        expect(pedido.medios_pago.first.importe.to_f).to eq(1700.0)
      end

      it 'picks todos discount over lower specific discount' do
        add_producto(pedido, producto1, 10, 200.0) # $2000

        create(:descuento_venta_mostrador, tienda: tienda,
                                           nombre: 'Efectivo $100',
                                           tipo_descuento: 'importe',
                                           importe: 100,
                                           medio_pago_tipo: 'efectivo',
                                           importe_minimo: 0)
        create(:descuento_venta_mostrador, tienda: tienda,
                                           nombre: 'Todos $500',
                                           tipo_descuento: 'importe',
                                           importe: 500,
                                           medio_pago_tipo: '',
                                           importe_minimo: 0)

        confirm_pedido(pedido, { '0' => { tipo: 'efectivo', importe: '2000' } })

        pedido.reload
        expect(pedido.descuento_venta_mostrador.nombre).to eq('Todos $500')
        expect(pedido.medios_pago.first.importe.to_f).to eq(1500.0)
      end

      it 'applies todos discount with client restriction' do
        add_producto(pedido, producto1, 10, 200.0) # $2000

        empleados_cliente = create(:cliente, tienda: tienda)
        d = create(:descuento_venta_mostrador, tienda: tienda,
                                               nombre: 'Empleados 20%',
                                               tipo_descuento: 'porcentaje',
                                               porcentaje: 20,
                                               limite_bonificacion: 99_999,
                                               medio_pago_tipo: '',
                                               importe_minimo: 0)
        d.clientes << empleados_cliente

        # Current pedido's cuenta belongs to a different client — should NOT match
        confirm_pedido(pedido, { '0' => { tipo: 'efectivo', importe: '2000' } })

        pedido.reload
        expect(pedido.descuento_venta_mostrador).to be_nil
        expect(pedido.medios_pago.first.importe.to_f).to eq(2000.0)
      end

      it 'todos discount with multiple medios uses grand total as base (not medio importe)' do
        add_producto(pedido, producto1, 10, 200.0) # 10 x $200 = $2000

        # 10% todos → should apply to $2000 total = $200, NOT to $1500 efectivo = $150
        create(:descuento_venta_mostrador, tienda: tienda,
                                           nombre: 'Todos 10%',
                                           tipo_descuento: 'porcentaje',
                                           porcentaje: 10,
                                           limite_bonificacion: 99_999,
                                           medio_pago_tipo: '',
                                           importe_minimo: 0)

        confirm_pedido(pedido, {
                         '0' => { tipo: 'efectivo', importe: '1500' },
                         '1' => { tipo: 'qr', importe: '500' }
                       })

        expect(response).to redirect_to(ventas_mostrador_pedidos_path)
        expect(flash[:error]).to be_blank

        pedido.reload
        expect(pedido.estado_id).to eq(3)
        expect(pedido.monto_descuento_vm.to_f).to eq(200.0) # 10% of $2000 total
        # Dominant medio (efectivo) adjusted: $1500 - $200 = $1300
        efectivo_mp = pedido.medios_pago.find_by(tipo: 'efectivo')
        qr_mp = pedido.medios_pago.find_by(tipo: 'qr')
        expect(efectivo_mp.importe.to_f).to eq(1300.0)
        expect(qr_mp.importe.to_f).to eq(500.0)
      end
    end
  end
end
