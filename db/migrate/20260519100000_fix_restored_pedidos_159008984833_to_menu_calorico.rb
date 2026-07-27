# Follow-up to 20260518100000_restore_pedidos_for_mp_payment_159008984833.
#
# The original recovery migration hard-coded productos 1805/1905 ("Sandwich de
# bondiola" / "Milanesa de carne picada"). Those IDs actually point at
# tienda-2 productos and were wrong. The real cart was:
#
#   - 1 x "Menú Calórico Estudiantil (350gr)" (producto id 2488) for 2026-05-18
#   - 1 x "Menú Calórico Estudiantil (350gr)" (producto id 2488) for 2026-05-19
#
# (The "18" / "19" in the MP description were the delivery dates, not part of
# a product name.) This producto is a menú diario, so each productos_solicitados
# row must also be linked to the existing MenuDiario for that day in tienda 1.
#
# This migration:
#   - locates the 2 pedidos via pagos_electronicos.pago_id
#   - lower-id pedido → fecha 2026-05-18, higher-id pedido → fecha 2026-05-19
#   - rewrites productos_solicitados.producto_id to 2488
#   - links productos_solicitados.menu_diario_id to the MenuDiario already
#     defined for tienda 1 on that date that includes producto 2488
#
# Idempotent: re-running after a successful run is a no-op.
class FixRestoredPedidos159008984833ToMenuCalorico < ActiveRecord::Migration[7.1]
  PAGO_ID     = 159_008_984_833
  TIENDA_ID   = 1
  PRODUCTO_ID = 2488
  FECHA_18    = Date.new(2026, 5, 18)
  FECHA_19    = Date.new(2026, 5, 19)
  TIPO_MENU_DIARIO_ID = 1 # MenusDiarios::Tipo[:menu_diario].id

  def up
    pedido_ids = connection.select_values(<<~SQL.squish).map(&:to_i).sort
      SELECT DISTINCT pedido_id
      FROM pagos_electronicos
      WHERE pago_id = #{PAGO_ID}
    SQL

    if pedido_ids.size != 2
      say "Expected 2 pedidos for MP #{PAGO_ID}, found #{pedido_ids.size}: #{pedido_ids.inspect}. Aborting.", true
      return
    end

    unless connection.select_value("SELECT id FROM productos WHERE id = #{PRODUCTO_ID} AND tienda_id = #{TIENDA_ID}")
      say "Producto #{PRODUCTO_ID} not found in tienda #{TIENDA_ID}. Aborting.", true
      return
    end

    menu_18 = find_menu_diario(FECHA_18)
    menu_19 = find_menu_diario(FECHA_19)

    unless menu_18 && menu_19
      say "MenuDiario missing for tienda #{TIENDA_ID} with producto #{PRODUCTO_ID}: " \
          "#{FECHA_18}=#{menu_18.inspect}, #{FECHA_19}=#{menu_19.inspect}. Aborting.", true
      return
    end

    say_with_time "Fixing pedidos #{pedido_ids.inspect} → producto #{PRODUCTO_ID}, menús #{menu_18}/#{menu_19}" do
      ActiveRecord::Base.transaction do
        pedido_18, pedido_19 = pedido_ids
        update_pedido(pedido_18, FECHA_18)
        update_pedido(pedido_19, FECHA_19)
        update_producto_solicitado(pedido_18, menu_18)
        update_producto_solicitado(pedido_19, menu_19)
        say "pedido #{pedido_18} → fecha #{FECHA_18}, menu_diario #{menu_18}", true
        say "pedido #{pedido_19} → fecha #{FECHA_19}, menu_diario #{menu_19}", true
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Manual reconciliation only.'
  end

  private

  def find_menu_diario(fecha)
    fecha_q = connection.quote(fecha.strftime('%Y-%m-%d'))
    id = connection.select_value(<<~SQL.squish)
      SELECT md.id
      FROM menus_diarios md
      INNER JOIN menus_diarios_productos mdp ON mdp.menu_diario_id = md.id
      WHERE md.tienda_id = #{TIENDA_ID}
        AND md.fecha = #{fecha_q}
        AND md.tipo_id = #{TIPO_MENU_DIARIO_ID}
        AND mdp.producto_id = #{PRODUCTO_ID}
        AND md.discontinued_at IS NULL
      LIMIT 1
    SQL
    id&.to_i
  end

  def update_pedido(pedido_id, fecha)
    fecha_q = connection.quote(fecha.strftime('%Y-%m-%d'))
    now = connection.quote(Time.current.utc.strftime('%Y-%m-%d %H:%M:%S'))
    connection.execute(
      "UPDATE pedidos SET fecha = #{fecha_q}, updated_at = #{now} WHERE id = #{pedido_id}"
    )
  end

  def update_producto_solicitado(pedido_id, menu_diario_id)
    connection.execute(<<~SQL.squish)
      UPDATE productos_solicitados
      SET producto_id = #{PRODUCTO_ID}, menu_diario_id = #{menu_diario_id}
      WHERE pedido_id = #{pedido_id}
    SQL
  end
end
