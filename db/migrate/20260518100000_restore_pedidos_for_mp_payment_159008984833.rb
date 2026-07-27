# One-shot data recovery migration for incident 2026-05-17.
#
# Background: MercadoPago payment 159008984833 ($14,820) for PedidoMultiple 78
# was approved at 21:52:32 (-03). At 21:52:37 another user (7388) in the same
# cuenta hit "Vaciar Carrito" on a sibling shell and triggered the
# (now-fixed) `vaciar_carrito_pendiente!` cross-user destroy path. That wiped:
#
#   - pedido 670846 (Sandwich de bondiola, producto 1805, $7410)
#   - pedido 670859 (Milanesa de carne picada, producto 1905, $7410)
#   - PedidoMultiple 78
#
# The MercadoPago webhook retry then found no group and exited silently, so
# no PagoElectronico row was created either. This migration restores both
# pedidos and a PagoElectronico per pedido tying them to MP 159008984833, so
# accounting / cobros reconciliation can find the payment.
#
# Idempotent: if PagoElectronico for pago_id=159008984833 already exists, the
# migration is a no-op.
class RestorePedidosForMpPayment159008984833 < ActiveRecord::Migration[7.1]
  PAGO_ID    = 159_008_984_833
  USUARIO_ID = 6180
  CUENTA_ID  = 101
  TIENDA_ID  = 1
  FECHA      = Date.new(2026, 5, 18)
  # estado_id 3 = confirmado, facturado=true, cobrado=true, stock_reducido=true
  ESTADO_CONFIRMADO = 3

  ITEMS = [
    { producto_id: 1805, descripcion: 'Sandwich de bondiola', precio: 7410.00, cantidad: 1 },
    { producto_id: 1905, descripcion: 'Milanesa de carne picada', precio: 7410.00, cantidad: 1 }
  ].freeze

  def up
    if connection.select_value("SELECT COUNT(*) FROM pagos_electronicos WHERE pago_id = #{PAGO_ID}").to_i.positive?
      say "PagoElectronico for MP #{PAGO_ID} already exists — skipping recovery.", true
      return
    end

    usuario_exists = connection.select_value("SELECT id FROM usuarios WHERE id = #{USUARIO_ID}")
    cuenta_exists  = connection.select_value("SELECT id FROM cuentas WHERE id = #{CUENTA_ID}")
    tienda_exists  = connection.select_value("SELECT id FROM tiendas WHERE id = #{TIENDA_ID}")
    unless usuario_exists && cuenta_exists && tienda_exists
      say "Missing prerequisites — usuario=#{usuario_exists.inspect} cuenta=#{cuenta_exists.inspect} tienda=#{tienda_exists.inspect}. Aborting.", true
      return
    end

    missing_productos = ITEMS.map { |i| i[:producto_id] }.reject do |pid|
      connection.select_value("SELECT id FROM productos WHERE id = #{pid}")
    end
    if missing_productos.any?
      say "Missing productos: #{missing_productos.inspect}. Aborting.", true
      return
    end

    say_with_time "Restoring 2 pedidos + 2 pagos_electronicos for MP #{PAGO_ID} ($14,820)" do
      now = connection.quote(Time.current.utc.strftime('%Y-%m-%d %H:%M:%S'))
      fecha_q = connection.quote(FECHA.strftime('%Y-%m-%d'))

      ActiveRecord::Base.transaction do
        ITEMS.each do |item|
          codigo = connection.select_value(
            "SELECT COALESCE(MAX(codigo), 0) + 1 FROM pedidos WHERE tienda_id = #{TIENDA_ID}"
          ).to_i

          connection.execute(<<~SQL.squish)
            INSERT INTO pedidos
              (autor_id, usuario_id, fecha, codigo, estado_id, created_at, updated_at,
               facturado, envio_a_domicilio, cuenta_id, pedido_para_empresa, tienda_id,
               venta_mostrador, cobrado, costo_envio_domicilio, stock_reducido)
            VALUES
              (#{USUARIO_ID}, #{USUARIO_ID}, #{fecha_q}, #{codigo}, #{ESTADO_CONFIRMADO},
               #{now}, #{now}, 1, 0, #{CUENTA_ID}, 0, #{TIENDA_ID}, 0, 1, 0.0, 1)
          SQL
          pedido_id = connection.select_value('SELECT LAST_INSERT_ID()').to_i

          descripcion_q = connection.quote(item[:descripcion])
          precio_q      = item[:precio]
          cantidad_q    = item[:cantidad]

          connection.execute(<<~SQL.squish)
            INSERT INTO productos_solicitados
              (pedido_id, producto_id, cantidad, precio_unitario, precio_con_descuento)
            VALUES
              (#{pedido_id}, #{item[:producto_id]}, #{cantidad_q}, #{precio_q}, #{precio_q})
          SQL

          connection.execute(<<~SQL.squish)
            INSERT INTO pagos_electronicos
              (pedido_id, pago_id, transaction_amount, total_paid_amount,
               net_received_amount, status, status_detail, currency_id,
               payment_method_id, payment_type_id, installments,
               date_created, date_approved, date_last_updated, description)
            VALUES
              (#{pedido_id}, #{PAGO_ID}, #{precio_q}, #{precio_q}, #{precio_q},
               'approved', 'accredited', 'ARS', 'account_money', 'account_money', 1,
               '2026-05-17 21:52:32', '2026-05-17 21:52:32', '2026-05-17 21:52:32',
               #{descripcion_q})
          SQL

          say "Created pedido id=#{pedido_id} codigo=#{codigo} producto=#{item[:producto_id]} importe=#{precio_q}", true
        end
      end
    end

    say <<~WARN, true
      ⚠️  MANUAL FOLLOW-UP REQUIRED:
        - Stock for productos #{ITEMS.map { |i| i[:producto_id] }.join(', ')} was NOT reduced at the time of the incident.
          Verify physical stock matches the system or run a manual `Productos::Stock#ajustar_stock`.
        - Kitchen never received these pedidos in real time — confirm with operations whether the order was prepared and delivered.
        - No Factura/Recibo (Comprobantes) was generated. Run `pedido.crear_factura(autor)` followed by `confirmar!`/`cobrar!`
          for each recovered pedido if accounting requires it. Or generate manually from the admin UI.
        - The pedidos were inserted with estado=3 (confirmado), facturado=1, cobrado=1, stock_reducido=1, so the
          UI will treat them as fully complete. Adjust if reconciliation requires otherwise.
    WARN
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Manual reconciliation only — refusing to delete recovered payment data.'
  end
end
