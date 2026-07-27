class ConsolidateDuplicateClientes < ActiveRecord::Migration[7.1]
  # Step 9 of clientes-shared migration: merge duplicate cliente rows that
  # were created independently per-tienda before Step 2 introduced the
  # clientes_tiendas HABTM. Two clientes are considered duplicates when:
  #   * they share the same non-blank CUIT (dashes are stripped before
  #     comparison) — nombre is NOT used to distinguish; any two records with
  #     the same CUIT are the same legal entity regardless of how the name was
  #     typed.
  #   * Clientes with a blank/null CUIT are NOT merged by CUIT (they have no
  #     CUIT to compare). The only exception is "Consumidor Final" (see below).
  #
  # Special case: rows with nombre = "Consumidor Final" are ALL collapsed by
  # name alone, regardless of CUIT — every tienda historically has its own
  # dummy/blank CUIT for the generic walk-in customer, but it's the same
  # logical entity. The canonical row (lowest id) keeps its own CUIT value;
  # the duplicates' CUITs are discarded.
  #
  # The cliente with the LOWEST id is kept as canonical; all FK references in
  # child tables are rewritten to point at it, the duplicate's tiendas are
  # unioned onto its clientes_tiendas access list, and the duplicate row is
  # deleted.
  #
  # After merging clientes, duplicate cuentas within the same cliente are also
  # merged: cuentas sharing the same normalized nombre under the same cliente_id
  # are collapsed (lowest id wins). All FK references to the duplicate cuenta
  # are repointed at the canonical cuenta. Idempotent — re-running on a clean
  # db is a no-op.

  # Tables with a plain `cliente_id` FK and no uniqueness constraint involving it.
  # A simple UPDATE is enough to re-point them at the canonical.
  SIMPLE_FK_TABLES = %w[
    cuentas
    configuraciones_impositivas
    clientes_pedidos_cocina
    clientes_categorias
    clientes_precios
  ].freeze

  # Tables with a plain `cuenta_id` FK. Simple UPDATE to repoint duplicates.
  CUENTA_FK_TABLES = %w[
    pedidos
    comprobantes
    movimientos_cbles
    medios_pago
    usuarios
  ].freeze

  # Tables that have a UNIQUE index on (cliente_id, other_id). Naively updating
  # cliente_id can hit the unique index when the canonical already has a row
  # for the same `other_id`. For these we INSERT IGNORE first (to copy the
  # rows that don't already exist on the canonical), then DELETE the
  # duplicate's rows.
  #   table_name => other_column
  UNIQUE_JOIN_TABLES = {
    'clientes_tiendas' => :tienda_id,
    'clientes_turnos_entrega' => :turno_entrega_id,
    'descuentos_venta_mostrador_clientes' => :descuento_venta_mostrador_id
  }.freeze

  def up
    duplicate_grupos_clientes.each do |group|
      canonical_id, *duplicate_ids = group.sort
      duplicate_ids.each { |dup_id| merge_cliente_into(canonical_id, dup_id) }
    end

    merge_duplicate_cuentas
    share_consumidor_final_with_all_tiendas
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Cliente consolidation cannot be reversed: the duplicate rows and their FK history are gone.'
  end

  private

  # ─── Cliente dedup ────────────────────────────────────────────────────────

  # Returns an array of arrays, each containing the ids of clientes that
  # should be collapsed together. Singletons are excluded.
  def duplicate_grupos_clientes
    # Pass 1: "Consumidor Final" rows — merge by name alone (ignore CUIT).
    cf_sql = <<~SQL
      SELECT GROUP_CONCAT(id ORDER BY id) AS ids
      FROM clientes
      WHERE LOWER(TRIM(nombre)) = 'consumidor final'
      HAVING COUNT(*) > 1
    SQL

    # Pass 2: all other rows that have a non-blank CUIT — merge by CUIT alone.
    # CUIT values may be stored with or without dashes (e.g. "30590354798" vs
    # "30-59035479-8"). Strip all non-digit characters before comparing.
    cuit_sql = <<~SQL
      SELECT GROUP_CONCAT(id ORDER BY id) AS ids
      FROM clientes
      WHERE LOWER(TRIM(nombre)) != 'consumidor final'
        AND NULLIF(REGEXP_REPLACE(TRIM(cuit), '[^0-9]', ''), '') IS NOT NULL
      GROUP BY REGEXP_REPLACE(TRIM(cuit), '[^0-9]', '')
      HAVING COUNT(*) > 1
    SQL

    conn = ActiveRecord::Base.connection
    (conn.select_values(cf_sql) + conn.select_values(cuit_sql)).map do |csv|
      csv.split(',').map(&:to_i)
    end
  end

  def merge_cliente_into(canonical_id, duplicate_id)
    ActiveRecord::Base.transaction do
      UNIQUE_JOIN_TABLES.each do |table, other_col|
        copy_unique_join_rows(table, other_col, canonical_id, duplicate_id)
      end

      SIMPLE_FK_TABLES.each do |table|
        next unless ActiveRecord::Base.connection.table_exists?(table)

        execute(
          "UPDATE #{quote_table(table)} SET cliente_id = #{quote(canonical_id)} " \
          "WHERE cliente_id = #{quote(duplicate_id)}"
        )
      end

      execute("DELETE FROM clientes WHERE id = #{quote(duplicate_id)}")
    end
  end

  # ─── Consumidor Final → all tiendas ──────────────────────────────────────

  # Ensure the canonical "Consumidor Final" cliente is accessible from every
  # tienda in the system (INSERT IGNORE is idempotent).
  def share_consumidor_final_with_all_tiendas
    return unless ActiveRecord::Base.connection.table_exists?('clientes_tiendas')

    cf_id = ActiveRecord::Base.connection.select_value(
      "SELECT id FROM clientes WHERE LOWER(TRIM(nombre)) = 'consumidor final' ORDER BY id LIMIT 1"
    )
    return unless cf_id

    tienda_ids = ActiveRecord::Base.connection.select_values('SELECT id FROM tiendas')
    tienda_ids.each do |tid|
      execute(
        "INSERT IGNORE INTO clientes_tiendas (cliente_id, tienda_id) VALUES (#{quote(cf_id)}, #{quote(tid)})"
      )
    end
  end

  # ─── Cuenta dedup ────────────────────────────────────────────────────────

  # After clientes have been merged, a single cliente may own multiple cuentas
  # with the same nombre (one per original per-tienda cliente row). Merge them:
  # keep the lowest id, repoint all FK child tables at it, delete the duplicate.
  def merge_duplicate_cuentas
    return unless ActiveRecord::Base.connection.table_exists?('cuentas')

    duplicate_grupos_cuentas.each do |group|
      canonical_id, *duplicate_ids = group.sort
      duplicate_ids.each { |dup_id| merge_cuenta_into(canonical_id, dup_id) }
    end
  end

  def duplicate_grupos_cuentas
    sql = <<~SQL
      SELECT GROUP_CONCAT(id ORDER BY id) AS ids
      FROM cuentas
      GROUP BY
        cliente_id,
        LOWER(TRIM(nombre))
      HAVING COUNT(*) > 1
    SQL

    ActiveRecord::Base.connection.select_values(sql).map do |csv|
      csv.split(',').map(&:to_i)
    end
  end

  def merge_cuenta_into(canonical_id, duplicate_id)
    ActiveRecord::Base.transaction do
      CUENTA_FK_TABLES.each do |table|
        next unless ActiveRecord::Base.connection.table_exists?(table)

        execute(
          "UPDATE #{quote_table(table)} SET cuenta_id = #{quote(canonical_id)} " \
          "WHERE cuenta_id = #{quote(duplicate_id)}"
        )
      end

      execute("DELETE FROM cuentas WHERE id = #{quote(duplicate_id)}")
    end
  end

  # ─── Helpers ─────────────────────────────────────────────────────────────
  # rows from the duplicate that don't already exist on the canonical, then
  # delete the duplicate's rows.
  def copy_unique_join_rows(table, other_col, canonical_id, duplicate_id)
    return unless ActiveRecord::Base.connection.table_exists?(table)

    quoted_table = quote_table(table)
    quoted_other = quote_column(other_col.to_s)

    execute <<~SQL
      INSERT IGNORE INTO #{quoted_table} (cliente_id, #{quoted_other})
      SELECT #{quote(canonical_id)}, #{quoted_other}
      FROM #{quoted_table}
      WHERE cliente_id = #{quote(duplicate_id)}
    SQL

    execute("DELETE FROM #{quoted_table} WHERE cliente_id = #{quote(duplicate_id)}")
  end

  def execute(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  def quote(val)
    ActiveRecord::Base.connection.quote(val)
  end

  def quote_table(name)
    ActiveRecord::Base.connection.quote_table_name(name)
  end

  def quote_column(name)
    ActiveRecord::Base.connection.quote_column_name(name)
  end
end
