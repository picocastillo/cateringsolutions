class DropClientesTiendaIdAndAddCuentasNroIndex < ActiveRecord::Migration[7.1]
  # Step 8 of clientes-shared migration:
  # 1. Drop the legacy `clientes.tienda_id` column. The `clientes_tiendas`
  #    HABTM (added in Step 2) is now the single source of truth for which
  #    tiendas a cliente is available in.
  # 2. Add a unique index on `cuentas.nro`. Step 7 renumbered every cuenta
  #    via the global `cuentas_globales` generator so this index is now safe.
  def up
    if index_exists?(:clientes, :tienda_id, name: 'index_clientes_on_tienda_id')
      remove_index :clientes, name: 'index_clientes_on_tienda_id'
    end

    if column_exists?(:clientes, :tienda_id)
      remove_column :clientes, :tienda_id
    end

    unless index_exists?(:cuentas, :nro, unique: true)
      add_index :cuentas, :nro, unique: true, name: 'index_cuentas_on_nro_unique'
    end
  end

  def down
    if index_exists?(:cuentas, :nro, unique: true)
      remove_index :cuentas, name: 'index_cuentas_on_nro_unique'
    end

    unless column_exists?(:clientes, :tienda_id)
      add_column :clientes, :tienda_id, :integer
      add_index :clientes, :tienda_id, name: 'index_clientes_on_tienda_id'

      # Best-effort backfill from clientes_tiendas (picks the lowest tienda_id per cliente).
      execute <<~SQL
        UPDATE clientes c
        SET tienda_id = (
          SELECT MIN(ct.tienda_id) FROM clientes_tiendas ct WHERE ct.cliente_id = c.id
        )
      SQL
    end
  end
end
