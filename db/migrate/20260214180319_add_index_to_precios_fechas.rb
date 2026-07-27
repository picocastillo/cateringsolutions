class AddIndexToPreciosFechas < ActiveRecord::Migration[5.2]
  def change
    add_index :precios, [:producto_id, :fecha_desde, :fecha_hasta], name: 'index_precios_on_producto_fechas'
    add_index :clientes_precios, [:precio_id, :cliente_id], name: 'index_clientes_precios_on_precio_cliente'
  end
end
