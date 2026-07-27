class AddVenderEnCarritoFlags < ActiveRecord::Migration[7.1]
  def change
    add_column :tiendas,    :muestra_mas_productos_por_categoria, :boolean, default: false, null: false
    add_column :categorias, :vender_en_carrito,                   :boolean, default: false, null: false
  end
end
