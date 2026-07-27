class AddLocalAtencionCarritoToTiendas < ActiveRecord::Migration[7.1]
  def change
    add_reference :tiendas, :local_atencion_carrito, foreign_key: { to_table: :locales }, null: true
  end
end
