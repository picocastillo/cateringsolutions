class AddMostrarComoNuevoHastaToProductos < ActiveRecord::Migration[5.2]
  def change
    add_column :productos, :mostrar_como_nuevo_hasta, :date
  end
end
