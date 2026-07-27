class DedupeProductosSolicitadosYRenglones < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    dedupe_renglones
    dedupe_productos_solicitados
    add_unique_indexes
  end

  def down
    remove_index :productos_solicitados, name: 'index_productos_solicitados_unique_per_pedido'
    execute 'ALTER TABLE productos_solicitados DROP COLUMN menu_diario_id_norm'
    remove_index :renglones, name: 'index_renglones_unique_per_comprobante_producto'
  end

  private

  # The same race condition that duplicated productos_solicitados also
  # duplicated the corresponding renglones inside the generated facturas (and a
  # few notas de crédito). All observed renglon dup groups have uniform
  # precio_unitario, tasa_iva_id and categoria_id, and zero pesable dups, so
  # summing cantidad into the MIN(id) row preserves comprobante.total exactly.
  #
  # NC renglones reference factura renglones via comprobante_afectado_id; we
  # redirect any such pointers to the keeper BEFORE deletion.
  def dedupe_renglones
    execute <<~SQL
      CREATE TEMPORARY TABLE _renglon_keepers (
        comprobante_id INT NOT NULL,
        producto_id INT NOT NULL,
        keep_id INT NOT NULL,
        PRIMARY KEY (comprobante_id, producto_id),
        KEY (keep_id)
      )
    SQL
    execute <<~SQL
      INSERT INTO _renglon_keepers (comprobante_id, producto_id, keep_id)
      SELECT comprobante_id, producto_id, MIN(id)
      FROM renglones
      WHERE producto_id IS NOT NULL
      GROUP BY comprobante_id, producto_id
      HAVING COUNT(*) > 1
    SQL

    execute <<~SQL
      UPDATE renglones nc
      JOIN renglones dup ON dup.id = nc.comprobante_afectado_id
      JOIN _renglon_keepers k
        ON k.comprobante_id = dup.comprobante_id
       AND k.producto_id    = dup.producto_id
      SET nc.comprobante_afectado_id = k.keep_id
      WHERE dup.id <> k.keep_id
    SQL

    execute <<~SQL
      UPDATE renglones r
      JOIN (
        SELECT k.keep_id, SUM(r2.cantidad) AS total_cantidad
        FROM _renglon_keepers k
        JOIN renglones r2
          ON r2.comprobante_id = k.comprobante_id
         AND r2.producto_id    = k.producto_id
        GROUP BY k.keep_id
      ) g ON g.keep_id = r.id
      SET r.cantidad = g.total_cantidad
    SQL

    execute <<~SQL
      DELETE r FROM renglones r
      JOIN _renglon_keepers k
        ON k.comprobante_id = r.comprobante_id
       AND k.producto_id    = r.producto_id
      WHERE r.id <> k.keep_id
    SQL

    execute 'DROP TEMPORARY TABLE _renglon_keepers'
  end

  # For non-pesable rows we sum cantidad; for pesable rows cantidad stays 1 and
  # we sum peso. When duplicates had different precio_unitario (18 of 475
  # groups), we keep the MIN(id) row's price.
  def dedupe_productos_solicitados
    execute <<~SQL
      UPDATE productos_solicitados ps
      JOIN (
        SELECT MIN(id) AS keep_id,
               SUM(cantidad) AS total_cantidad,
               SUM(COALESCE(peso, 0)) AS total_peso,
               MAX(pesable) AS pesable_flag
        FROM productos_solicitados
        GROUP BY pedido_id, producto_id, COALESCE(menu_diario_id, 0)
        HAVING COUNT(*) > 1
      ) g ON g.keep_id = ps.id
      SET ps.cantidad = CASE WHEN g.pesable_flag = 1 THEN 1 ELSE g.total_cantidad END,
          ps.peso     = CASE WHEN g.pesable_flag = 1 THEN g.total_peso ELSE ps.peso END
    SQL

    execute <<~SQL
      DELETE ps FROM productos_solicitados ps
      JOIN (
        SELECT pedido_id, producto_id, COALESCE(menu_diario_id, 0) AS mdi, MIN(id) AS keep_id
        FROM productos_solicitados
        GROUP BY pedido_id, producto_id, COALESCE(menu_diario_id, 0)
        HAVING COUNT(*) > 1
      ) g
        ON ps.pedido_id   = g.pedido_id
       AND ps.producto_id = g.producto_id
       AND COALESCE(ps.menu_diario_id, 0) = g.mdi
       AND ps.id <> g.keep_id
    SQL
  end

  # productos_solicitados uses a STORED generated column so NULL menu_diario_id
  # is normalized to 0 (MariaDB treats multiple NULLs as distinct in a unique
  # index, otherwise dups on menu-less productos would slip through).
  # renglones relies on standard NULL semantics: custom items (producto_id NULL)
  # are intentionally allowed to repeat.
  def add_unique_indexes
    execute <<~SQL
      ALTER TABLE productos_solicitados
      ADD COLUMN menu_diario_id_norm INT AS (COALESCE(menu_diario_id, 0)) STORED
    SQL
    add_index :productos_solicitados,
              %i[pedido_id producto_id menu_diario_id_norm],
              unique: true,
              name: 'index_productos_solicitados_unique_per_pedido'

    add_index :renglones,
              %i[comprobante_id producto_id],
              unique: true,
              name: 'index_renglones_unique_per_comprobante_producto'
  end
end
