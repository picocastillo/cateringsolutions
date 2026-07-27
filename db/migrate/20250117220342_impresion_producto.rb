class ImpresionProducto < ActiveRecord::Migration[5.2]
  def change
    add_column :tiendas, :impresion_productos, :boolean, default: false
    Tiendas::Tienda.reset_column_information
    execute "update tiendas set impresion_productos = true where id = 2"
  end
end
