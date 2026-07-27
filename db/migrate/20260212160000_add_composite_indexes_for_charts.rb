class AddCompositeIndexesForCharts < ActiveRecord::Migration[5.2]
  def change
    # pedidos: composite (tienda_id, estado_id, fecha) covers all inicio chart queries
    # Leftmost prefix (tienda_id) replaces standalone index
    add_index :pedidos, [:tienda_id, :estado_id, :fecha], name: 'index_pedidos_on_tienda_estado_fecha'
    remove_index :pedidos, name: 'index_pedidos_on_tienda_id'

    # pedidos: composite (cuenta_id, estado_id, fecha) covers all cliente chart queries
    # Leftmost prefix (cuenta_id) replaces standalone index
    add_index :pedidos, [:cuenta_id, :estado_id, :fecha], name: 'index_pedidos_on_cuenta_estado_fecha'
    remove_index :pedidos, name: 'index_pedidos_on_cuenta_id'

    # productos_solicitados: composite (pedido_id, producto_id) covers JOIN + GROUP BY
    # Leftmost prefix (pedido_id) replaces standalone index
    add_index :productos_solicitados, [:pedido_id, :producto_id], name: 'index_prod_solicitados_on_pedido_producto'
    remove_index :productos_solicitados, name: 'index_productos_solicitados_on_pedido_id'
  end
end
