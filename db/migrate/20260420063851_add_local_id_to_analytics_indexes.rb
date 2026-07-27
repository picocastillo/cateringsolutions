class AddLocalIdToAnalyticsIndexes < ActiveRecord::Migration[7.1]
  def change
    # Composite index for pedidos analytics queries:
    # WHERE tienda_id = ? AND estado_id IN (...) AND local_id = ? AND fecha ...
    add_index :pedidos, [:tienda_id, :local_id, :estado_id, :fecha],
              name: 'idx_pedidos_tienda_local_estado_fecha'

    # Composite index for comprobantes analytics queries:
    # WHERE tienda_id = ? AND estado_id IN (...) AND local_id = ? AND type = ? AND fecha_emision ...
    add_index :comprobantes, [:tienda_id, :local_id, :estado_id, :type, :fecha_emision],
              name: 'idx_comprobantes_tienda_local_estado_type_fecha'
  end
end
