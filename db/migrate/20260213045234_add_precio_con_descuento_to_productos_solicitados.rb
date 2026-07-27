class AddPrecioConDescuentoToProductosSolicitados < ActiveRecord::Migration[5.2]
  def change
    add_column :productos_solicitados, :precio_con_descuento, :decimal, precision: 12, scale: 2
  end
end
