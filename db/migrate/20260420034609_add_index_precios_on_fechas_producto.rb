class AddIndexPreciosOnFechasProducto < ActiveRecord::Migration[7.1]
  def change
    add_index :precios, [:fecha_desde, :fecha_hasta, :producto_id], name: 'index_precios_on_fechas_producto'
  end
end
