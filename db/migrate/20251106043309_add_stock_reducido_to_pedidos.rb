class AddStockReducidoToPedidos < ActiveRecord::Migration[5.2]
  def change
    add_column :pedidos, :stock_reducido, :boolean, default: false, null: false
    add_index :pedidos, :stock_reducido
  end
end
