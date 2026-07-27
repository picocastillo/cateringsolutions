class CreateProductosStockMovimientos < ActiveRecord::Migration[5.2]
  def change
    create_table :productos_stock_movimientos do |t|
      t.references :stock, null: false, foreign_key: { to_table: :productos_stocks }
      t.references :usuario, null: true, foreign_key: { to_table: :usuarios }
      
      t.string :tipo, null: false
      t.integer :cantidad, null: false
      t.integer :cantidad_anterior, null: false
      t.integer :cantidad_nueva, null: false
      
      t.text :motivo
      t.text :observaciones
      
      t.datetime :fecha, null: false
      t.timestamps null: false
    end
    
    # Índices para optimizar consultas
    add_index :productos_stock_movimientos, :stock_id, name: 'index_stock_movimientos_stock'
    add_index :productos_stock_movimientos, :tipo, name: 'index_stock_movimientos_tipo'
    add_index :productos_stock_movimientos, :fecha, name: 'index_stock_movimientos_fecha'
    add_index :productos_stock_movimientos, [:stock_id, :fecha], name: 'index_stock_movimientos_stock_fecha'
    add_index :productos_stock_movimientos, [:tipo, :fecha], name: 'index_stock_movimientos_tipo_fecha'
  end
end