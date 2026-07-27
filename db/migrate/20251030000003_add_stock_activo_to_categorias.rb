class AddStockActivoToCategorias < ActiveRecord::Migration[5.2]
  def change
    add_column :categorias, :stock_activo, :boolean, default: false, null: false
    
    # Enable stock_activo for Bebida and Kiosco categories
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE categorias 
          SET stock_activo = true 
          WHERE nombre IN ('Bebida', 'Kiosco')
        SQL
      end
    end
  end
end
