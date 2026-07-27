class AddCuponIdToPedidosAndCanceladoToCupones < ActiveRecord::Migration[5.2]
  def change
    add_reference :pedidos, :cupon, foreign_key: { to_table: :cupones }, index: true
    add_column :cupones, :cancelado, :boolean, default: false, null: false
    add_index :cupones, :cancelado
  end
end
