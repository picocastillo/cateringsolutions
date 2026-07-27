class AddPerformanceIndexesFeb2026 < ActiveRecord::Migration[5.2]
  def change
    # VentasMostrador#index: WHERE(autor_id, estado_id, tienda_id, venta_mostrador) + ORDER(updated_at)
    add_index :pedidos, [:tienda_id, :venta_mostrador, :estado_id, :autor_id],
              name: 'index_pedidos_on_mostrador_lookup'

    # CargasSimples _input_para partial: WHERE(cuenta_id) + para IS NOT NULL
    add_index :pedidos, [:cuenta_id, :para],
              name: 'index_pedidos_on_cuenta_para'

    # productos_solicitados: standalone pedido_id for aggregate queries (SUM, COUNT)
    # The composite (pedido_id, producto_id) exists but a covering index with cantidad
    # and precio_con_descuento helps the footer_aggregates pluck avoid table lookups
    add_index :productos_solicitados, [:pedido_id],
              name: 'index_productos_solicitados_on_pedido_id'

    # VentasMostrador barcode lookup: find_by(codigos_externos: c) + tienda_id
    add_index :productos, [:tienda_id, :codigos_externos],
              name: 'index_productos_on_tienda_codigos_externos'
  end
end
