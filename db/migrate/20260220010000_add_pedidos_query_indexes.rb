class AddPedidosQueryIndexes < ActiveRecord::Migration[7.1]
  def change
    # Primary composite index for the most common query pattern:
    # WHERE tienda_id = ? ORDER BY fecha DESC, codigo DESC LIMIT 10
    # Also helps footer_aggregates via tienda_id prefix matching.
    add_index :pedidos, [:tienda_id, :fecha, :codigo], name: :idx_pedidos_tienda_fecha_codigo

    # Extends existing (tienda_id, estado_id, fecha) by adding codigo
    # to cover ORDER BY without filesort when estado is filtered.
    add_index :pedidos, [:tienda_id, :estado_id, :fecha, :codigo], name: :idx_pedidos_tienda_estado_fecha_codigo

    # Covers client-user queries: WHERE tienda_id = ? AND cuenta_id IN (?) ORDER BY fecha DESC, codigo DESC
    add_index :pedidos, [:tienda_id, :cuenta_id, :fecha, :codigo], name: :idx_pedidos_tienda_cuenta_fecha_codigo

    # Drop redundant indexes now covered by the new composites:
    # (fecha) alone is never queried without tienda_id
    remove_index :pedidos, name: :index_pedidos_fecha
    # (fecha, codigo) is never queried without tienda_id
    remove_index :pedidos, name: :index_pedidos_on_fecha_and_codigo
    # (tienda_id, estado_id, fecha) is a prefix of the new 4-column index
    remove_index :pedidos, name: :index_pedidos_on_tienda_estado_fecha
  end
end
