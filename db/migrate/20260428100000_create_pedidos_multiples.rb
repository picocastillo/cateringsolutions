class CreatePedidosMultiples < ActiveRecord::Migration[7.0]
  def change
    create_table :pedidos_multiples do |t|
      t.bigint :usuario_id, null: false
      t.integer :estado, null: false, default: 0
      t.timestamps
    end

    add_index :pedidos_multiples, :usuario_id
    add_column :pedidos, :pedido_multiple_id, :bigint
    add_index :pedidos, :pedido_multiple_id

    add_column :pagos_electronicos, :pedido_multiple_id, :bigint
    add_index :pagos_electronicos, :pedido_multiple_id
  end
end
