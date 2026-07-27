class AddVisibilityFlagsToTiendas < ActiveRecord::Migration[7.1]
  def change
    add_column :tiendas, :muestra_mas_productos,  :boolean, default: false, null: false
    add_column :tiendas, :muestra_menus_del_dia,  :boolean, default: false, null: false

    reversible do |dir|
      dir.up do
        # Tienda 1: Menús del Día + Más Productos
        execute <<~SQL
          UPDATE tiendas
             SET muestra_menus_del_dia      = 1,
                 muestra_mas_productos      = 1,
                 soporta_productos_diarios  = 0
           WHERE id = 1
        SQL

        # Tienda 2: solo Nuestras opciones del día (productos diarios)
        execute <<~SQL
          UPDATE tiendas
             SET muestra_menus_del_dia      = 0,
                 muestra_mas_productos      = 0,
                 soporta_productos_diarios  = 1
           WHERE id = 2
        SQL

        # Tienda 3: ninguno
        execute <<~SQL
          UPDATE tiendas
             SET muestra_menus_del_dia      = 0,
                 muestra_mas_productos      = 0,
                 soporta_productos_diarios  = 0
           WHERE id = 3
        SQL
      end
    end
  end
end
