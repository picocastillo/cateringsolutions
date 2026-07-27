class AddPerformanceIndexesFeb2026V2 < ActiveRecord::Migration[7.1]
  def change
    # CargasSimples index: ORDER BY updated_at DESC with tienda_id filter
    add_index :pedidos, [:tienda_id, :updated_at],
              name: 'index_pedidos_on_tienda_updated_at'
  end
end
