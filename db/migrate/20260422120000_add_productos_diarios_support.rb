class AddProductosDiariosSupport < ActiveRecord::Migration[7.1]
  def change
    add_column :tiendas, :soporta_productos_diarios, :boolean, default: false, null: false

    add_column :menus_diarios, :tipo_id, :integer, default: 1, null: false
    add_index :menus_diarios, %i[tienda_id fecha tipo_id], name: 'idx_menus_diarios_tienda_fecha_tipo'

    reversible do |dir|
      dir.up do
        # Existing rows already get the column default; make intent explicit.
        execute 'UPDATE menus_diarios SET tipo_id = 1 WHERE tipo_id IS NULL'
      end
    end
  end
end
