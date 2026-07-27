class AddCompositeIndexToProductos < ActiveRecord::Migration[7.1]
  def change
    add_index :productos, [:tienda_id, :discontinued_at, :pesable, :categoria_id],
              name: 'index_productos_on_tienda_discontinued_pesable_categoria'
  end
end
