class AddPerformanceIndexesMarch2026 < ActiveRecord::Migration[7.1]
  def change
    # Covers financieros query: WHERE cuenta_id IN (...) AND estado_id IN (2,3) AND fecha_emision BETWEEN
    add_index :comprobantes, [:cuenta_id, :estado_id, :fecha_emision],
              name: 'idx_comprobantes_cuenta_estado_fecha_emision'

    # Covers stats queries: JOIN on pedido_id + WHERE menu_diario_id IS NULL + GROUP BY producto_id
    add_index :productos_solicitados, [:pedido_id, :menu_diario_id, :producto_id],
              name: 'idx_prod_solicitados_pedido_menu_producto'
  end
end
