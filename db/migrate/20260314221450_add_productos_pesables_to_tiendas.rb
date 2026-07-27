class AddProductosPesablesToTiendas < ActiveRecord::Migration[7.1]
  def change
    add_column :tiendas, :productos_pesables, :boolean, default: false, null: false

    reversible do |dir|
      dir.up do
        execute "UPDATE tiendas SET productos_pesables = 1 WHERE id = 3"
      end
    end
  end
end
