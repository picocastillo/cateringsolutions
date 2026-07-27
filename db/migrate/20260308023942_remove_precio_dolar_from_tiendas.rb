class RemovePrecioDolarFromTiendas < ActiveRecord::Migration[7.1]
  def change
    remove_column :tiendas, :precio_dolar, :float
  end
end
