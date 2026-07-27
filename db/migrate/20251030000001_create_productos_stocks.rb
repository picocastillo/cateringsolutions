class CreateProductosStocks < ActiveRecord::Migration[5.2]
  def change
    create_table :productos_stocks do |t|
      t.references :producto, null: false, foreign_key: true
      t.references :tienda, null: false, foreign_key: true
      t.references :local, null: true, foreign_key: true
      
      t.integer :cantidad_actual, default: 0, null: false
      t.integer :cantidad_minima, default: 0, null: false
      t.integer :cantidad_maxima, null: true
      
      t.text :observaciones
      t.boolean :activo, default: true, null: false
      
      t.timestamps null: false
    end
    
    # Índices para optimizar consultas
    add_index :productos_stocks, [:producto_id, :tienda_id, :local_id], unique: true, name: 'index_stocks_producto_tienda_local'
    add_index :productos_stocks, [:tienda_id, :local_id], name: 'index_stocks_tienda_local'
    add_index :productos_stocks, :cantidad_actual, name: 'index_stocks_cantidad_actual'
    add_index :productos_stocks, [:cantidad_actual, :cantidad_minima], name: 'index_stocks_cantidad_comparison'
  end
end