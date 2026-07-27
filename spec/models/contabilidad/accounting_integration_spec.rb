require 'rails_helper'

RSpec.describe 'Accounting Integration: Pedidos vs Cuentas Corrientes', type: :model do
  # ============================================================================
  # Setup: 1 tienda, 1 cliente, 2 cuentas, 2 usuarios, products with stock,
  # cupones of both types, ~30 pedidos across both cuentas/users.
  #
  # Flow: Create pedidos → apply cupones to some → aceptar! → confirmar!
  #       Then verify:
  #       - Facturas & NCs created correctly
  #       - Stock reduced by exact quantities ordered
  #       - Movimientos saldo matches pedido effective totals (after discounts)
  # ============================================================================

  let!(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Contable', maneja_stock: true) }

  let!(:cliente) do
    Clientes::Cliente.create!(
      nombre: 'Cliente Contable SA',
      cuit: CuitGenerator.generate_valid_cuit,
      dia_inicio_ciclo_facturacion: 1,
      vencimiento_a: 30,
      horario_corte_pedidos: '23:59',
      tienda: tienda,
      cuenta_corriente: true
    )
  end

  let!(:cuenta_1) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Sucursal Norte', cuenta_corriente_parcial: true) }
  let!(:cuenta_2) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Sucursal Sur', cuenta_corriente_parcial: true) }

  let!(:usuario_1) do
    Usuarios::Usuario.create!(
      nombre: 'Juan Norte', login: 'juannorte', email: 'juan@norte.com',
      password: 'password123', password_confirmation: 'password123',
      tipo_usuario_id: 1, dni: 30_100_200, cuenta: cuenta_1,
      visualizando_tienda: tienda
    )
  end

  let!(:usuario_2) do
    Usuarios::Usuario.create!(
      nombre: 'María Sur', login: 'mariasur', email: 'maria@sur.com',
      password: 'password123', password_confirmation: 'password123',
      tipo_usuario_id: 1, dni: 30_300_400, cuenta: cuenta_2,
      visualizando_tienda: tienda
    )
  end

  # Admin user (needed as autor for confirmar!)
  let!(:admin) do
    Usuarios::Usuario.create!(
      nombre: 'Admin', login: 'admincontable', email: 'admin@contable.com',
      password: 'password123', password_confirmation: 'password123',
      tipo_usuario_id: 2, dni: 20_000_001,
      visualizando_tienda: tienda
    )
  end

  # Comprobante tipos (Factura and NotaCredito)
  let!(:tipo_factura) do
    Comprobantes::Tipo.find_by(codigo: 1) ||
      Comprobantes::Tipo.create!(desc: 'Remito', codigo: 1, clase: 'Ventas::Facturacion::Factura')
  end
  let!(:tipo_nc) do
    Comprobantes::Tipo.find_by(codigo: 3) ||
      Comprobantes::Tipo.create!(desc: 'Nota de Crédito C', codigo: 3, letra: 'C',
                                 clase: 'Ventas::Facturacion::NotaCredito', debitan: false)
  end

  # Categories with stock enabled
  let!(:cat_bebidas) { Productos::Categoria.create!(nombre: 'Bebidas', tienda: tienda, stock_activo: true) }
  let!(:cat_comidas) { Productos::Categoria.create!(nombre: 'Comidas', tienda: tienda, stock_activo: true) }
  let!(:cat_postres) { Productos::Categoria.create!(nombre: 'Postres', tienda: tienda, stock_activo: false) }

  # Products — varied prices
  let!(:productos) do
    items = [
      { nombre: 'Agua Mineral', categoria: cat_bebidas, precio: 500.0 },
      { nombre: 'Gaseosa Cola', categoria: cat_bebidas, precio: 750.0 },
      { nombre: 'Jugo Natural', categoria: cat_bebidas, precio: 900.0 },
      { nombre: 'Milanesa', categoria: cat_comidas, precio: 2500.0 },
      { nombre: 'Empanada', categoria: cat_comidas, precio: 350.0 },
      { nombre: 'Pizza', categoria: cat_comidas, precio: 1800.0 },
      { nombre: 'Hamburguesa', categoria: cat_comidas, precio: 2200.0 },
      { nombre: 'Flan', categoria: cat_postres, precio: 1200.0 },
      { nombre: 'Helado', categoria: cat_postres, precio: 1500.0 }
    ]

    items.map do |attrs|
      producto = Productos::Producto.create!(
        nombre: attrs[:nombre], categoria: attrs[:categoria], tienda: tienda
      )
      Productos::Precio.create!(
        producto: producto, importe: attrs[:precio],
        fecha_desde: 1.month.ago, fecha_hasta: 1.year.from_now
      )
      producto
    end
  end

  # Set up stock for products in stock-enabled categories (bebidas + comidas = 7 products)
  let!(:initial_stock) { 500 }
  let!(:stocks) do
    productos.select { |p| p.categoria.stock_activo? }.map do |producto|
      stock = producto.stock_for_local(nil) || producto.ensure_stock_exists(nil)
      stock.update!(cantidad_actual: initial_stock, cantidad_minima: 10)
      stock
    end
  end

  # Cupones: one fixed amount, one percentage
  let!(:cupon_fijo) do
    Cupones::Cupon.create!(
      tienda: tienda, tipo_descuento: 'importe', importe: 500.0,
      fecha_vencimiento: 1.month.from_now, codigo: 'FIJO500'
    )
  end
  let!(:cupon_porcentaje) do
    Cupones::Cupon.create!(
      tienda: tienda, tipo_descuento: 'porcentaje', porcentaje: 15.0,
      limite_bonificacion: 2000.0, fecha_vencimiento: 1.month.from_now, codigo: 'PCT15'
    )
  end

  # We'll create individual cupones for each pedido that needs one (cupon has_one pedido)
  def next_weekday
    d = Date.current + 1
    d += 1 while d.saturday? || d.sunday?
    d
  end

  def crear_cupon_fijo(index)
    Cupones::Cupon.create!(
      tienda: tienda, tipo_descuento: 'importe', importe: 500.0,
      fecha_vencimiento: 1.month.from_now, codigo: "FIJO#{index}"
    )
  end

  def crear_cupon_porcentaje(index)
    Cupones::Cupon.create!(
      tienda: tienda, tipo_descuento: 'porcentaje', porcentaje: 15.0,
      limite_bonificacion: 2000.0, fecha_vencimiento: 1.month.from_now, codigo: "PCT#{index}"
    )
  end

  # Helper: create a pedido with random products
  def crear_pedido(usuario, cuenta, fecha: next_weekday)
    pedido = Pedidos::Pedido.new(
      usuario: usuario, autor: usuario, cuenta: cuenta,
      fecha: fecha, estado_id: 1, tienda: tienda
    )
    pedido.save!

    # Add 2-5 random products with random quantities
    num_items = rand(2..5)
    productos.sample(num_items).each do |producto|
      precio = Productos::Precio.find_by(producto: producto)
      ps = Productos::ProductoSolicitado.new(
        pedido: pedido, producto: producto,
        cantidad: rand(1..4), precio_unitario: precio.importe
      )
      ps.save(validate: false)
    end

    pedido.reload
    pedido
  end

  # Helper: aceptar + confirmar a pedido (full cuenta corriente flow)
  def aceptar_y_confirmar!(pedido)
    pedido.aceptar!
    pedido.confirmar!(admin)
  end

  describe 'Full accounting cycle with 30 pedidos, cupones and stock' do
    let!(:pedidos) { [] }
    let!(:pedidos_con_cupon_fijo) { [] }
    let!(:pedidos_con_cupon_porcentaje) { [] }
    let!(:pedidos_sin_cupon) { [] }

    before do
      cupon_fijo_idx = 100
      cupon_pct_idx = 100

      # Create 15 pedidos for usuario_1 / cuenta_1
      15.times do |i|
        pedido = crear_pedido(usuario_1, cuenta_1)
        pedidos << pedido

        case i % 3
        when 0 # Apply fixed cupon
          cupon = crear_cupon_fijo(cupon_fijo_idx += 1)
          pedido.aplicar_cupon!(cupon)
          pedidos_con_cupon_fijo << pedido
        when 1 # Apply percentage cupon
          cupon = crear_cupon_porcentaje(cupon_pct_idx += 1)
          pedido.aplicar_cupon!(cupon)
          pedidos_con_cupon_porcentaje << pedido
        else # No cupon
          pedidos_sin_cupon << pedido
        end
      end

      # Create 15 pedidos for usuario_2 / cuenta_2
      15.times do |i|
        pedido = crear_pedido(usuario_2, cuenta_2)
        pedidos << pedido

        case i % 3
        when 0
          cupon = crear_cupon_fijo(cupon_fijo_idx += 1)
          pedido.aplicar_cupon!(cupon)
          pedidos_con_cupon_fijo << pedido
        when 1
          cupon = crear_cupon_porcentaje(cupon_pct_idx += 1)
          pedido.aplicar_cupon!(cupon)
          pedidos_con_cupon_porcentaje << pedido
        else
          pedidos_sin_cupon << pedido
        end
      end

      # Accept and confirm all pedidos
      pedidos.each { |p| aceptar_y_confirmar!(p) }
    end

    # ========================================================================
    # 1. Basic sanity: all pedidos confirmed with facturas
    # ========================================================================
    it 'creates 30 confirmed pedidos with facturas' do
      expect(pedidos.count).to eq(30)
      pedidos.each do |p|
        p.reload
        expect(p.estado_id).to eq(3), "Pedido ##{p.id} should be confirmado (3), got #{p.estado_id}"

        facturas = p.comprobantes.select { |c| c.is_a?(Ventas::Facturacion::Factura) }
        expect(facturas).not_to be_empty, "Pedido ##{p.id} should have a factura"
        facturas.each do |f|
          expect(f.confirmado?).to be(true), "Factura ##{f.id} should be confirmado"
          expect(f.total).to be > 0
        end
      end
    end

    # ========================================================================
    # 2. Pedidos with cupones should have NCs created
    # ========================================================================
    it 'creates nota de crédito for each pedido with cupon' do
      pedidos_con_descuento = pedidos_con_cupon_fijo + pedidos_con_cupon_porcentaje
      expect(pedidos_con_descuento.count).to eq(20)

      pedidos_con_descuento.each do |p|
        p.reload
        ncs = p.comprobantes.select { |c| c.is_a?(Ventas::Facturacion::NotaCredito) }
        expect(ncs).not_to be_empty, "Pedido ##{p.id} with cupon '#{p.cupon&.codigo}' should have a NC"
        ncs.each do |nc|
          expect(nc.confirmado?).to be(true), "NC ##{nc.id} should be confirmado"
          expect(nc.total).to be > 0
        end
      end
    end

    it 'does not create NC for pedidos without cupon' do
      pedidos_sin_cupon.each do |p|
        p.reload
        ncs = p.comprobantes.select { |c| c.is_a?(Ventas::Facturacion::NotaCredito) }
        expect(ncs).to be_empty, "Pedido ##{p.id} without cupon should not have a NC"
      end
    end

    # ========================================================================
    # 3. Factura total = sum of original prices (precio_unitario * cantidad)
    # ========================================================================
    it 'factura total equals sum of original prices for each pedido' do
      pedidos.each do |p|
        p.reload
        expected = p.productos_solicitados.sum { |ps| ps.precio_unitario * ps.cantidad }
        factura = p.comprobantes.detect { |c| c.is_a?(Ventas::Facturacion::Factura) }

        expect(factura.total).to be_within(0.01).of(expected),
                                 "Pedido ##{p.id}: factura total #{factura.total} != expected #{expected}"
      end
    end

    # ========================================================================
    # 4. NC total = discount amount for pedidos with cupones
    # ========================================================================
    it 'NC total equals cupon discount amount for each discounted pedido' do
      (pedidos_con_cupon_fijo + pedidos_con_cupon_porcentaje).each do |p|
        p.reload
        nc = p.comprobantes.detect { |c| c.is_a?(Ventas::Facturacion::NotaCredito) }
        next unless nc # safety guard

        original_total = p.productos_solicitados.sum { |ps| ps.precio_unitario * ps.cantidad }
        expected_discount = p.cupon.descuento_para(original_total)

        expect(nc.total).to be_within(0.01).of(expected_discount),
                            "Pedido ##{p.id}: NC total #{nc.total} != expected discount #{expected_discount} " \
                            "(cupon: #{p.cupon.codigo}, tipo: #{p.cupon.tipo_descuento})"
      end
    end

    # ========================================================================
    # 5. KEY ACCOUNTING IDENTITY: Factura - NC = Effective pedido total
    #    For each pedido: factura.total - nc.total = pedido.importe_total
    # ========================================================================
    it 'factura.total - NC.total equals expected cupon discount for every pedido' do
      pedidos.each do |p|
        p.reload
        factura = p.comprobantes.detect { |c| c.is_a?(Ventas::Facturacion::Factura) }
        nc = p.comprobantes.detect { |c| c.is_a?(Ventas::Facturacion::NotaCredito) }

        net_factura = factura.total - (nc&.total || 0)

        # Expected: original total minus cupon discount (computed via cupon.descuento_para)
        original_total = p.productos_solicitados.sum { |ps| ps.precio_unitario * ps.cantidad }
        expected_discount = p.cupon ? p.cupon.descuento_para(original_total) : 0
        expected_net = original_total - expected_discount

        expect(net_factura).to be_within(0.01).of(expected_net),
                               "Pedido ##{p.id}: net factura #{net_factura} != expected #{expected_net} " \
                               "(original #{original_total} - discount #{expected_discount})"
      end
    end

    # ========================================================================
    # 6. CUENTA CORRIENTE SALDO: Sum of movimientos saldo per cuenta must match
    #    the sum of pedido effective totals for that cuenta
    # ========================================================================
    it 'movimientos saldo total per cuenta matches facturas minus NCs' do
      [cuenta_1, cuenta_2].each do |cuenta|
        pedidos_cuenta = pedidos.select { |p| p.cuenta_id == cuenta.id }

        # Expected: sum of (factura - NC) per pedido
        expected_saldo = pedidos_cuenta.sum do |p|
          p.reload
          original_total = p.productos_solicitados.sum { |ps| ps.precio_unitario * ps.cantidad }
          discount = p.cupon ? p.cupon.descuento_para(original_total) : 0
          original_total - discount
        end

        # Actual: sum of saldo from movimientos contables
        actual_saldo = Contabilidad::Movimiento
                       .where(cuenta_id: cuenta.id, tienda_id: tienda.id)
                       .where('saldo <> 0')
                       .sum(:saldo)

        expect(actual_saldo).to be_within(0.01).of(expected_saldo),
                                "Cuenta '#{cuenta.nombre}': movimientos saldo #{actual_saldo} != " \
                                "expected #{expected_saldo} from #{pedidos_cuenta.count} pedidos"
      end
    end

    # ========================================================================
    # 7. GRAND TOTAL: Total across ALL cuentas matches total across ALL pedidos
    # ========================================================================
    it 'grand total of all movimientos saldo equals grand total of all pedido net amounts' do
      expected_grand_total = pedidos.sum do |p|
        p.reload
        original_total = p.productos_solicitados.sum { |ps| ps.precio_unitario * ps.cantidad }
        discount = p.cupon ? p.cupon.descuento_para(original_total) : 0
        original_total - discount
      end

      actual_grand_total = Contabilidad::Movimiento
                           .where(tienda_id: tienda.id)
                           .where('saldo <> 0')
                           .sum(:saldo)

      expect(actual_grand_total).to be_within(0.01).of(expected_grand_total),
                                    "Grand total: movimientos #{actual_grand_total} != pedidos #{expected_grand_total}"
    end

    # ========================================================================
    # 8. Per-user totals: movimientos saldo filtered by pedido.usuario matches
    # ========================================================================
    it 'movimientos saldo per user matches sum of that user pedido net amounts' do
      { usuario_1 => cuenta_1, usuario_2 => cuenta_2 }.each do |usuario, cuenta|
        user_pedidos = pedidos.select { |p| p.usuario_id == usuario.id }
        expected = user_pedidos.sum do |p|
          p.reload
          original_total = p.productos_solicitados.sum { |ps| ps.precio_unitario * ps.cantidad }
          discount = p.cupon ? p.cupon.descuento_para(original_total) : 0
          original_total - discount
        end

        actual = Contabilidad::Movimiento
                 .where(cuenta_id: cuenta.id, tienda_id: tienda.id)
                 .where('saldo <> 0')
                 .sum(:saldo)

        expect(actual).to be_within(0.01).of(expected),
                          "User '#{usuario.nombre}': saldo #{actual} != expected #{expected}"
      end
    end

    # ========================================================================
    # 9. STOCK REDUCTION: Products in stock-enabled categories had their
    #    stock reduced by the total quantities ordered across all pedidos
    # ========================================================================
    it 'reduces stock by exact quantities ordered for stock-enabled products' do
      # Calculate expected stock reductions per product
      expected_reductions = Hash.new(0)
      pedidos.each do |p|
        p.reload
        p.productos_solicitados.each do |ps|
          next unless ps.producto.categoria.stock_activo?

          expected_reductions[ps.producto_id] += ps.cantidad
        end
      end

      # Verify each product's stock was reduced correctly
      expected_reductions.each do |producto_id, total_reducido|
        stock = Productos::Stock.find_by(producto_id: producto_id, local_id: nil, tienda_id: tienda.id)
        expect(stock).not_to be_nil, "Stock for producto #{producto_id} should exist"
        expect(stock.cantidad_actual).to eq(initial_stock - total_reducido),
                                         "Producto #{producto_id} (#{Productos::Producto.find(producto_id).nombre}): " \
                                         "stock #{stock.cantidad_actual} != expected #{initial_stock - total_reducido} " \
                                         "(initial #{initial_stock} - sold #{total_reducido})"
      end
    end

    it 'does not reduce stock for products in categories without stock_activo' do
      postres_products = productos.select { |p| p.categoria == cat_postres }
      postres_products.each do |producto|
        stock = Productos::Stock.find_by(producto_id: producto.id, local_id: nil, tienda_id: tienda.id)
        # Postres don't have stock_activo, so stock record should not exist or be unchanged
        expect(stock).to be_nil,
                         "Producto #{producto.nombre} (postres, stock_activo=false) should not have stock record"
      end
    end

    it 'creates stock movimientos of type salida/venta for every stock reduction' do
      pedidos.each do |p|
        p.reload
        p.productos_solicitados.each do |ps|
          next unless ps.producto.categoria.stock_activo?

          stock = Productos::Stock.find_by(producto_id: ps.producto_id, local_id: nil, tienda_id: tienda.id)
          movimientos = stock.stock_movimientos.where(tipo: 'salida')
          expect(movimientos).not_to be_empty,
                                     "Stock for #{ps.producto.nombre} should have 'salida' movements"
        end
      end
    end

    it 'marks all pedidos as stock_reducido' do
      pedidos.each do |p|
        p.reload
        expect(p.stock_reducido).to be(true),
                                    "Pedido ##{p.id} should have stock_reducido = true"
      end
    end

    # ========================================================================
    # 10. CUPON TYPE VERIFICATION: Fixed vs percentage discounts are correct
    # ========================================================================
    it 'fixed cupon NC total matches cupon discount amount' do
      pedidos_con_cupon_fijo.each do |p|
        p.reload
        nc = p.comprobantes.detect { |c| c.is_a?(Ventas::Facturacion::NotaCredito) }
        original_total = p.productos_solicitados.sum { |ps| ps.precio_unitario * ps.cantidad }
        expected_discount = p.cupon.descuento_para(original_total)

        expect(nc.total).to be_within(0.01).of(expected_discount),
                            "Pedido ##{p.id} fixed cupon: NC total #{nc.total} != expected #{expected_discount}"
      end
    end

    it 'percentage cupon discounts respect limite_bonificacion' do
      pedidos_con_cupon_porcentaje.each do |p|
        p.reload
        original_total = p.importe_total_sin_descuento.to_f
        discount = p.importe_descuento_cupon.to_f

        raw_discount = original_total * p.cupon.porcentaje / 100.0
        expected_discount = [raw_discount, p.cupon.limite_bonificacion].min
        expect(discount).to be_within(0.01).of(expected_discount),
                            "Pedido ##{p.id} percentage cupon: discount #{discount} != expected #{expected_discount} " \
                            "(#{p.cupon.porcentaje}% of #{original_total}, limit #{p.cupon.limite_bonificacion})"
      end
    end

    # ========================================================================
    # 11. DOUBLE-ENTRY VERIFICATION: Sum of all importe in movimientos = 0
    #     (facturas debit + NC credits should net to sum of pending saldos)
    # ========================================================================
    it 'total facturas importe minus total NCs importe equals total pending saldo' do
      facturas_total = Ventas::Facturacion::Factura
                       .joins(:pedido)
                       .where(pedidos: { tienda_id: tienda.id })
                       .where(estado_id: 2)
                       .sum(:total)

      ncs_total = Ventas::Facturacion::NotaCredito
                  .joins(:pedido)
                  .where(pedidos: { tienda_id: tienda.id })
                  .where(estado_id: 2)
                  .sum(:total)

      pending_saldo = Contabilidad::Movimiento
                      .where(tienda_id: tienda.id)
                      .where('saldo <> 0')
                      .sum(:saldo)

      expect(facturas_total - ncs_total).to be_within(0.01).of(pending_saldo),
                                            "Facturas (#{facturas_total}) - NCs (#{ncs_total}) != pending saldo (#{pending_saldo})"
    end

    # ========================================================================
    # 12. CONSISTENCY: Each movimiento's importe equals its comprobante's total
    # ========================================================================
    it 'each factura movimiento importe equals factura total' do
      Contabilidad::Movimiento
        .joins(:comprobante)
        .where(tienda_id: tienda.id)
        .where(comprobantes: { type: 'Ventas::Facturacion::Factura' })
        .where(imputado_id: nil) # Only the main movimiento, not afectacion entries
        .find_each do |mov|
          expect(mov.importe).to be_within(0.01).of(mov.comprobante.total),
                                 "Movimiento ##{mov.id}: importe #{mov.importe} != comprobante total #{mov.comprobante.total}"
        end
    end
  end
end
