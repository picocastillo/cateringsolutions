class UnassignConsumidorFinalFromPreciosTienda2 < ActiveRecord::Migration[7.1]
  def up
    cliente_ids = Clientes::Cliente
                  .where(tienda_id: 2)
                  .where('LOWER(nombre) = ?', 'consumidor final')
                  .pluck(:id)

    if cliente_ids.empty?
      say "No 'Consumidor Final' clientes found for tienda 2; nothing to do."
      return
    end

    # Only target precios in tienda 2 where Consumidor Final is the SOLE cliente.
    # If the precio has other clientes assigned, leave it alone.
    precio_ids = ActiveRecord::Base.connection.select_values(
      ActiveRecord::Base.send(:sanitize_sql_array, [
        "SELECT cp.precio_id
           FROM clientes_precios cp
           INNER JOIN precios p ON p.id = cp.precio_id
           INNER JOIN productos pr ON pr.id = p.producto_id
          WHERE pr.tienda_id = 2
            AND cp.cliente_id IN (?)
          GROUP BY cp.precio_id
         HAVING COUNT(*) = 1",
        cliente_ids
      ])
    )

    if precio_ids.empty?
      say "No precios found where 'Consumidor Final' is the only cliente; nothing to do."
      return
    end

    deleted = ActiveRecord::Base.connection.exec_delete(
      ActiveRecord::Base.send(:sanitize_sql_array, [
        "DELETE FROM clientes_precios WHERE cliente_id IN (?) AND precio_id IN (?)",
        cliente_ids, precio_ids
      ])
    )

    say "Removed #{deleted} clientes_precios rows where 'Consumidor Final' was the only cliente on a precio in tienda 2."
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
