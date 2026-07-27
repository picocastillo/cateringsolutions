class CreateClientesTiendas < ActiveRecord::Migration[7.1]
  def change
    create_table :clientes_tiendas, id: false do |t|
      t.references :cliente, null: false, foreign_key: true
      t.references :tienda,  null: false, foreign_key: true
    end
    add_index :clientes_tiendas, [:cliente_id, :tienda_id], unique: true, name: 'index_clientes_tiendas_uniq'
    add_index :clientes_tiendas, [:tienda_id, :cliente_id], name: 'index_clientes_tiendas_reverse'

    # Backfill: every existing cliente.tienda_id becomes a row in the join table.
    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          INSERT INTO clientes_tiendas (cliente_id, tienda_id)
          SELECT id, tienda_id FROM clientes WHERE tienda_id IS NOT NULL
        SQL
      end
    end
  end
end
