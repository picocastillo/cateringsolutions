class CreateInitialStockRecords < ActiveRecord::Migration[5.2]
  def up
    # Create stock records for existing products
    # Set 10000 initial stock for products in categories with stock_activo enabled (Bebida, Kiosco)
    # Using execute to avoid model loading issues during migration
    connection.execute(<<~SQL)
      INSERT INTO productos_stocks (producto_id, tienda_id, local_id, cantidad_actual, cantidad_minima, created_at, updated_at)
      SELECT 
        p.id as producto_id,
        p.tienda_id,
        NULL as local_id,
        CASE 
          WHEN c.stock_activo = 1 THEN 10000.0
          ELSE 0.0
        END as cantidad_actual,
        0.0 as cantidad_minima,
        NOW() as created_at,
        NOW() as updated_at
      FROM productos p
      INNER JOIN categorias c ON c.id = p.categoria_id
      LEFT JOIN productos_stocks ps ON ps.producto_id = p.id AND ps.local_id IS NULL
      WHERE ps.id IS NULL
    SQL

    puts "Created initial stock records for existing products (10000 for stock_activo categories)"
  end

  def down
    # Remove all stock records
    connection.execute("DELETE FROM productos_stocks")
    puts "Removed all stock records"
  end
end