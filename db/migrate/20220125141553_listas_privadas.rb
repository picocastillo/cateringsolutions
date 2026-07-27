class ListasPrivadas < ActiveRecord::Migration[5.2]
  def change
    add_column :clientes, :listas_de_precio_privada, :boolean, default: false, null: false
  end
end
