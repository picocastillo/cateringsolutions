class PedidosCocina < ActiveRecord::Migration[5.2]
  def change
    # Create the main pedidos_cocina table
    create_table :pedidos_cocina do |t|
      t.datetime :fecha
      t.string :descripcion
      t.integer :autor_id
      t.integer :codigo
      t.integer :tienda_id
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index %w[tienda_id fecha updated_at], name: 'associated_index'
      t.index :autor_id
      t.index :tienda_id
      t.index :fecha
      t.index :codigo
    end

    # Create join table for pedidos_cocina and usuarios (many-to-many)
    create_join_table :pedidos_cocina, :usuarios do |t|
      t.index :pedido_cocina_id
      t.index :usuario_id
    end

    # Create join table for pedidos_cocina and clientes (many-to-many)
    create_join_table :pedidos_cocina, :clientes do |t|
      t.index :pedido_cocina_id
      t.index :cliente_id
    end

    # Create join table for pedidos_cocina and cuentas (many-to-many)
    create_join_table :pedidos_cocina, :cuentas do |t|
      t.index :pedido_cocina_id
      t.index :cuenta_id
    end

    add_column :pedidos, :pedido_cocina_id, :integer, index: true, foreign_key: { to_table: :pedidos_cocina }
  end
end
