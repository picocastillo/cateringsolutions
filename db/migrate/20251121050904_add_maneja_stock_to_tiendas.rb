class AddManejaStockToTiendas < ActiveRecord::Migration[5.2]
  def change
    add_column :tiendas, :maneja_stock, :boolean, default: false, null: false
    
    # Enable stock management for tienda id 1 (Catering Solutions)
    reversible do |dir|
      dir.up do
        execute "UPDATE tiendas SET maneja_stock = TRUE WHERE id = 1"
      end
    end
  end
end
