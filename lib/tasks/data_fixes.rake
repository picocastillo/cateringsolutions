namespace :data_fixes do
  desc 'Detect duplicate productos_solicitados / renglones rows. Mails on any hit. Exit code 1 if dups exist.'
  task check_duplicates: :environment do
    conn = ActiveRecord::Base.connection
    ps_dups = conn.select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM (
        SELECT 1 FROM productos_solicitados
        GROUP BY pedido_id, producto_id, COALESCE(menu_diario_id,0)
        HAVING COUNT(*) > 1
      ) x
    SQL
    rg_dups = conn.select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM (
        SELECT 1 FROM renglones
        WHERE producto_id IS NOT NULL
        GROUP BY comprobante_id, producto_id
        HAVING COUNT(*) > 1
      ) x
    SQL

    msg = "data_fixes:check_duplicates -> productos_solicitados=#{ps_dups} renglones=#{rg_dups}"
    puts msg
    Rails.logger.info(msg)

    if ps_dups.positive? || rg_dups.positive?
      warn 'DUPLICATES DETECTED — investigate and re-run dedupe migration'
      exit 1
    end
  end

  desc 'Reassign comprobantes whose tienda_id differs from their pedido.tienda_id. DRY_RUN=1 (default) prints only.'
  task reassign_cross_tienda_comprobantes: :environment do
    dry_run = ENV['DRY_RUN'] != '0'
    log_path = Rails.root.join('log/cross_tienda_reassign.log')
    log = File.open(log_path, 'a')
    log.sync = true
    stamp = lambda { |msg|
  line = "[#{Time.current.iso8601}] #{msg}"
  puts line
  log.puts line
}

    stamp.call("=== reassign_cross_tienda_comprobantes (dry_run=#{dry_run}) ===")

    base = Comprobantes::Comprobante
           .where(type: ['Ventas::Facturacion::Factura', 'Ventas::Facturacion::NotaCredito', 'Ventas::Facturacion::NotaDebito'])
           .joins('JOIN pedidos p ON p.id = comprobantes.pedido_id')
           .where('comprobantes.tienda_id != p.tienda_id')

    ids = base.pluck('comprobantes.id, p.tienda_id, p.local_id')
    stamp.call("Found #{ids.size} cross-tienda comprobantes")

    processed = 0
    reassigned = 0
    skipped = 0

    Comprobantes::Comprobante.transaction do
      ids.each_slice(500) do |slice|
        Comprobantes::Comprobante.where(id: slice.map(&:first)).find_each do |cbte|
          processed += 1
          row = slice.find { |r| r[0] == cbte.id }
          correct_tienda = row[1]
          correct_local = row[2]
          wrong_tienda = cbte.tienda_id
          klass = cbte.type
          old_nro = cbte.nro

          if wrong_tienda == correct_tienda
            skipped += 1
            next
          end

          if dry_run
            stamp.call("DRY id=#{cbte.id} #{klass} tipo=#{cbte.tipo_id} #{wrong_tienda}/#{old_nro} -> " \
                       "tienda=#{correct_tienda} (new nro from tienda#{correct_tienda}_#{klass})")
          else
            new_nro = Infraestructura::GeneradorSecuencial.proximo("tienda#{correct_tienda}_#{klass}")
            cbte.update_columns(tienda_id: correct_tienda, local_id: correct_local, nro: new_nro)
            stamp.call("FIX id=#{cbte.id} #{klass} tipo=#{cbte.tipo_id} #{wrong_tienda}/#{old_nro} -> #{correct_tienda}/#{new_nro}")
          end
          reassigned += 1
        end
      end

      raise ActiveRecord::Rollback if dry_run
    end

    stamp.call("Done. processed=#{processed} reassigned=#{reassigned} skipped=#{skipped} dry_run=#{dry_run}")
  ensure
    log&.close
  end

  # Create facturas for confirmed pedidos (estado 3/4) that have products but zero ventas.
  # These pedidos should have been billed when confirmed; the factura is missing entirely.
  desc 'Create missing facturas for confirmed pedidos with no comprobantes. DRY_RUN=1 (default).'
  task crear_facturas_faltantes: :environment do
    dry_run = ENV['DRY_RUN'] != '0'
    log_path = Rails.root.join('log/reconciliacion_pedidos.log')
    log = File.open(log_path, 'a')
    log.sync = true
    stamp = lambda { |msg|
  line = "[#{Time.current.iso8601}] #{msg}"
  puts line
  log.puts line
}
    stamp.call("=== crear_facturas_faltantes (dry_run=#{dry_run}) ===")

    sql = <<~SQL.squish
      SELECT p.id, p.tienda_id, p.fecha, p.estado_id,
             COALESCE(ps.prod_total, 0) prod_total,
             COALESCE(vn.ventas_net, 0) ventas_net
      FROM pedidos p
      JOIN (SELECT pedido_id,
                   SUM(IF(peso IS NULL, cantidad * precio_con_descuento,
                                         cantidad * peso * precio_con_descuento)) prod_total
            FROM productos_solicitados GROUP BY pedido_id) ps ON ps.pedido_id = p.id
      LEFT JOIN (SELECT c.pedido_id,
                        SUM(IF(t.debitan = 1, c.total, -c.total)) ventas_net
                 FROM comprobantes c JOIN tipos_comprobantes t ON t.id = c.tipo_id
                 WHERE c.estado_id = 2 AND c.type LIKE 'Ventas::Facturacion::%'
                 GROUP BY c.pedido_id) vn ON vn.pedido_id = p.id
      WHERE p.estado_id IN (3, 4) AND ps.prod_total > 0
        AND COALESCE(vn.ventas_net, 0) = 0
    SQL

    rows = ActiveRecord::Base.connection.exec_query(sql).to_a
    stamp.call("Found #{rows.size} pedidos missing facturas")
    total_prod = rows.sum { |r| r['prod_total'].to_f }
    stamp.call("Sum of prod_total to recover into ventas: #{total_prod.round(2)}")

    created = 0
    failed = 0

    Pedidos::Pedido.transaction do
      rows.each do |r|
        pedido = Pedidos::Pedido.find(r['id'])
        u = pedido.autor || pedido.usuario
        unless u
          stamp.call("SKIP pedido=#{pedido.id} no autor/usuario")
          failed += 1
          next
        end

        # Confirm any pending factura first; only create a new one if none exists.
        pending_factura = pedido.comprobantes.where(type: 'Ventas::Facturacion::Factura', estado_id: 1).order(:created_at).last
        confirmed_factura = pedido.comprobantes.exists?(type: 'Ventas::Facturacion::Factura', estado_id: 2)

        if dry_run
          if pending_factura
            stamp.call("DRY pedido=#{pedido.id} confirm pending factura id=#{pending_factura.id} total=#{pending_factura.total}")
          elsif confirmed_factura
            stamp.call("SKIP pedido=#{pedido.id} has confirmed factura but ventas==0 (likely fully NC'd; needs manual review)")
            failed += 1
            next
          else
            stamp.call("DRY pedido=#{pedido.id} tienda=#{pedido.tienda_id} fecha=#{pedido.fecha} prod=#{r['prod_total']} -> create factura")
          end
          created += 1
        else
          begin
            if pending_factura
              pending_factura.confirmar(u).save!
              stamp.call("FIX pedido=#{pedido.id} confirmed factura id=#{pending_factura.id} nro=#{pending_factura.reload.nro} total=#{pending_factura.total}")
            elsif confirmed_factura
              stamp.call("SKIP pedido=#{pedido.id} has confirmed factura but ventas==0; manual review")
              failed += 1
              next
            else
              factura = pedido.send(:crear_factura, u)
              factura.save!
              factura.confirmar(u).save!
              stamp.call("FIX pedido=#{pedido.id} created factura id=#{factura.id} nro=#{factura.nro} total=#{factura.total}")
            end
            created += 1
          rescue StandardError => e
            stamp.call("ERROR pedido=#{pedido.id}: #{e.class}: #{e.message}")
            failed += 1
          end
        end
      end
      raise ActiveRecord::Rollback if dry_run
    end

    stamp.call("Done. created=#{created} failed=#{failed} dry_run=#{dry_run}")
  ensure
    log&.close
  end

  # Find pedidos with duplicate confirmed facturas (same total, no compensating NC)
  # and anular the extras via NotaCredito.
  desc 'Anular duplicate facturas on OVER pedidos. DRY_RUN=1 (default).'
  task anular_facturas_duplicadas: :environment do
    dry_run = ENV['DRY_RUN'] != '0'
    log_path = Rails.root.join('log/reconciliacion_pedidos.log')
    log = File.open(log_path, 'a')
    log.sync = true
    stamp = lambda { |msg|
  line = "[#{Time.current.iso8601}] #{msg}"
  puts line
  log.puts line
}
    stamp.call("=== anular_facturas_duplicadas (dry_run=#{dry_run}) ===")

    # OVER pedidos: ventas_net > prod_total + envio
    sql = <<~SQL.squish
      SELECT p.id pedido_id, p.tienda_id, p.fecha,
             ROUND(ps.prod_total + p.costo_envio_domicilio, 2) expected,
             ROUND(vn.ventas_net, 2) ventas,
             ROUND(vn.ventas_net - ps.prod_total - p.costo_envio_domicilio, 2) gap
      FROM pedidos p
      JOIN (SELECT pedido_id,
                   SUM(IF(peso IS NULL, cantidad * precio_con_descuento,
                                         cantidad * peso * precio_con_descuento)) prod_total
            FROM productos_solicitados GROUP BY pedido_id) ps ON ps.pedido_id = p.id
      JOIN (SELECT c.pedido_id, SUM(IF(t.debitan = 1, c.total, -c.total)) ventas_net
            FROM comprobantes c JOIN tipos_comprobantes t ON t.id = c.tipo_id
            WHERE c.estado_id = 2 AND c.type LIKE 'Ventas::Facturacion::%'
            GROUP BY c.pedido_id) vn ON vn.pedido_id = p.id
      WHERE p.estado_id IN (3, 4)
        AND vn.ventas_net - ps.prod_total - p.costo_envio_domicilio > 0.01
    SQL

    rows = ActiveRecord::Base.connection.exec_query(sql).to_a
    stamp.call("Found #{rows.size} OVER pedidos to inspect")

    anulled = 0
    skipped = 0

    Pedidos::Pedido.transaction do
      rows.each do |row|
        pedido = Pedidos::Pedido.find(row['pedido_id'])
        gap = row['gap'].to_f

        facturas = pedido.comprobantes.where(estado_id: 2, type: 'Ventas::Facturacion::Factura').order(:fecha_emision, :id).to_a
        ncs = pedido.comprobantes.where(estado_id: 2, type: 'Ventas::Facturacion::NotaCredito').to_a

        # Mark facturas already cancelled by an NC (one-to-one via afectaciones)
        cancelled_factura_ids = ncs.flat_map { |nc| nc.afectados.map(&:id) }.compact.to_set
        live_facturas = facturas.reject { |f| cancelled_factura_ids.include?(f.id) }

        next if live_facturas.size <= 1

        # Sort live facturas by fecha_emision asc, keep oldest, anular extras
        live_facturas = live_facturas.sort_by { |f| [f.fecha_emision || Time.zone.at(0), f.id] }
        keep = live_facturas.first
        extras = live_facturas[1..]

        # Safety guard: only anular when each extra's total <= remaining gap
        running_gap = gap
        to_anular = []
        extras.each do |f|
          break if running_gap < f.total - 0.01

          to_anular << f
          running_gap -= f.total
        end

        if to_anular.empty?
          skipped += 1
          stamp.call("SKIP pedido=#{pedido.id} gap=#{gap} live=#{live_facturas.size} keep=#{keep.id}/#{keep.nro} extras=#{extras.map do |f|
  "#{f.id}/#{f.nro}=#{f.total}"
end.join(',')}")
          next
        end

        if dry_run
          to_anular.each do |f|
            stamp.call("DRY pedido=#{pedido.id} anular factura id=#{f.id} nro=#{f.nro} total=#{f.total} (keep id=#{keep.id} nro=#{keep.nro})")
          end
          anulled += to_anular.size
        else
          to_anular.each do |f|
            pedido.send(:anular_factura, pedido.autor, f)
            stamp.call("FIX pedido=#{pedido.id} anulled factura id=#{f.id} nro=#{f.nro} total=#{f.total}")
            anulled += 1
          end
        end
      end
      raise ActiveRecord::Rollback if dry_run
    end

    stamp.call("Done. anulled=#{anulled} skipped=#{skipped} dry_run=#{dry_run}")
  ensure
    log&.close
  end

  # Detect and delete duplicate NCs: multiple confirmed NotaCredito comprobantes
  # that cancel the same factura (same afectado). Keeps the oldest, destroys the rest.
  desc 'Delete duplicate notas de credito cancelling the same factura. DRY_RUN=1 (default).'
  task eliminar_ncs_duplicadas: :environment do
    dry_run = ENV['DRY_RUN'] != '0'
    log_path = Rails.root.join('log/reconciliacion_pedidos.log')
    log = File.open(log_path, 'a')
    log.sync = true
    stamp = lambda { |msg|
  line = "[#{Time.current.iso8601}] #{msg}"
  puts line
  log.puts line
}
    stamp.call("=== eliminar_ncs_duplicadas (dry_run=#{dry_run}) ===")

    # Only true duplicates: same afectado_id AND same total (partial vs full credit notes
    # cancel the same factura for different amounts and are NOT duplicates).
    sql = <<~SQL.squish
      SELECT a.afectado_id, c.total, GROUP_CONCAT(c.id ORDER BY c.created_at) nc_ids, COUNT(*) n
      FROM comprobantes c
      JOIN afectaciones a ON a.comprobante_id = c.id
      WHERE c.type = 'Ventas::Facturacion::NotaCredito' AND c.estado_id = 2
      GROUP BY a.afectado_id, c.total
      HAVING COUNT(*) > 1
    SQL

    rows = ActiveRecord::Base.connection.exec_query(sql).to_a
    stamp.call("Found #{rows.size} facturas cancelled by multiple NCs")

    deleted = 0
    failed = 0

    Comprobantes::Comprobante.transaction do
      rows.each do |r|
        nc_ids = r['nc_ids'].split(',').map(&:to_i)
        # Keep oldest (first), destroy the rest
        keep_id = nc_ids.first
        dup_ids = nc_ids[1..]

        dup_ids.each do |nc_id|
          nc = Comprobantes::Comprobante.find(nc_id)
          if dry_run
            stamp.call("DRY destroy NC id=#{nc.id} nro=#{nc.nro} total=#{nc.total} pedido=#{nc.pedido_id} " \
                       "(keep NC id=#{keep_id} cancels factura id=#{r['afectado_id']})")
            deleted += 1
          else
            begin
              nc.destroy!
              stamp.call("FIX destroyed NC id=#{nc.id} nro=#{nc.nro} pedido=#{nc.pedido_id} (kept id=#{keep_id})")
              deleted += 1
            rescue StandardError => e
              stamp.call("ERROR NC id=#{nc.id}: #{e.class}: #{e.message}")
              failed += 1
            end
          end
        end
      end
      raise ActiveRecord::Rollback if dry_run
    end

    stamp.call("Done. deleted=#{deleted} failed=#{failed} dry_run=#{dry_run}")
  ensure
    log&.close
  end

  desc 'Run all reconciliation fixes (cancel + anular) and print final gap. DRY_RUN=1 (default).'
  task reconciliar_pedidos_vs_ventas: :environment do
    Rake::Task['data_fixes:crear_facturas_faltantes'].invoke
    Rake::Task['data_fixes:anular_facturas_duplicadas'].invoke
    Rake::Task['data_fixes:ajustar_productos_a_facturas'].invoke
    Rake::Task['data_fixes:cerrar_gap_residual'].invoke
    Rake::Task['data_fixes:print_gap_summary'].invoke
  end

  desc 'Run ALL post-release data fixes in order. MP reprocess always runs last. DRY_RUN=1 (default). Excludes destructive eliminar_ncs_duplicadas.'
  task run_all: :environment do
    Rake::Task['data_fixes:reassign_cross_tienda_comprobantes'].invoke
    Rake::Task['data_fixes:crear_facturas_faltantes'].invoke
    Rake::Task['data_fixes:anular_facturas_duplicadas'].invoke
    Rake::Task['data_fixes:ajustar_productos_a_facturas'].invoke
    Rake::Task['data_fixes:cerrar_gap_residual'].invoke
    Rake::Task['data_fixes:print_gap_summary'].invoke
    # MP reprocess MUST run last: it re-enqueues background jobs that may
    # create/confirm pedidos and comprobantes — running it before the
    # reconciliation tasks would leave new inconsistencies unhandled.
    Rake::Task['data_fixes:reprocess_missed_mp_payments'].invoke
  end

  desc 'Final reconciliation: scale ps.precio_con_descuento per pedido so sum(ps) = ventas_net - envio. DRY_RUN=1 (default).'
  task cerrar_gap_residual: :environment do
    dry_run = ENV['DRY_RUN'] != '0'
    log_path = Rails.root.join('log/reconciliacion_pedidos.log')
    log = File.open(log_path, 'a')
    log.sync = true
    stamp = lambda { |msg|
  line = "[#{Time.current.iso8601}] #{msg}"
  puts line
  log.puts line
}
    stamp.call("=== cerrar_gap_residual (dry_run=#{dry_run}) ===")

    sql = <<~SQL.squish
      SELECT p.id pedido_id,
             COALESCE(p.costo_envio_domicilio, 0) envio,
             ROUND(ps.prod_total, 6) prod_total,
             ROUND(COALESCE(vn.ventas_net, 0), 6) ventas_net
      FROM pedidos p
      JOIN (SELECT pedido_id,
                   SUM(IF(peso IS NULL, cantidad * precio_con_descuento,
                                         cantidad * peso * precio_con_descuento)) prod_total
            FROM productos_solicitados GROUP BY pedido_id) ps ON ps.pedido_id = p.id
      LEFT JOIN (SELECT c.pedido_id, SUM(IF(t.debitan = 1, c.total, -c.total)) ventas_net
                 FROM comprobantes c JOIN tipos_comprobantes t ON t.id = c.tipo_id
                 WHERE c.estado_id = 2 AND c.type LIKE 'Ventas::Facturacion::%'
                 GROUP BY c.pedido_id) vn ON vn.pedido_id = p.id
      WHERE p.estado_id IN (3, 4)
        AND ABS(COALESCE(vn.ventas_net, 0) - ps.prod_total - COALESCE(p.costo_envio_domicilio,0)) > 0.01
    SQL

    rows = ActiveRecord::Base.connection.exec_query(sql).to_a
    stamp.call("Found #{rows.size} pedidos with residual gap")

    fixed = 0
    skipped = 0
    ActiveRecord::Base.transaction do
      rows.each do |row|
        pid = row['pedido_id']
        envio = row['envio'].to_f
        target = row['ventas_net'].to_f - envio
        current_total = row['prod_total'].to_f

        if target <= 0
          stamp.call("SKIP pedido=#{pid} target<=0 (ventas_net=#{row['ventas_net']}, envio=#{envio})")
          skipped += 1
          next
        end

        if current_total <= 0
          stamp.call("SKIP pedido=#{pid} ps total<=0")
          skipped += 1
          next
        end

        factor = target / current_total
        stamp.call("FIX pedido=#{pid} target=#{target.round(2)} current=#{current_total.round(2)} factor=#{factor.round(6)}")

        next if dry_run

        # Scale each ps.precio_con_descuento by factor; round to 6 decimals, then fix last row to absorb rounding drift
        pss = Productos::ProductoSolicitado.where(pedido_id: pid).order(:id).to_a
        new_total = 0.0
        pss.each_with_index do |ps, i|
          new_pcd = (ps.precio_con_descuento.to_f * factor).round(6)
          line_qty = (ps.peso ? ps.cantidad.to_f * ps.peso.to_f : ps.cantidad.to_f)
          if i == pss.size - 1
            # Last row: absorb residual rounding
            remaining = target - new_total
            new_pcd = (remaining / line_qty).round(6) if line_qty.positive?
          end
          Productos::ProductoSolicitado.where(id: ps.id).update_all(precio_con_descuento: new_pcd)
          new_total += new_pcd * line_qty
        end

        fixed += 1
      end
    end

    stamp.call("Done. fixed=#{fixed} skipped=#{skipped} dry_run=#{dry_run}")
  ensure
    log&.close
  end

  desc 'Align productos_solicitados to confirmed factura/NC renglones (facturas are AFIP truth). DRY_RUN=1 (default).'
  task ajustar_productos_a_facturas: :environment do
    dry_run = ENV['DRY_RUN'] != '0'
    log_path = Rails.root.join('log/reconciliacion_pedidos.log')
    log = File.open(log_path, 'a')
    log.sync = true
    stamp = lambda { |msg|
  line = "[#{Time.current.iso8601}] #{msg}"
  puts line
  log.puts line
}
    stamp.call("=== ajustar_productos_a_facturas (dry_run=#{dry_run}) ===")

    sql = <<~SQL.squish
      SELECT p.id pedido_id,
             ROUND(ps.prod_total, 2) prod_total,
             ROUND(COALESCE(vn.ventas_net, 0), 2) ventas_net,
             ROUND(COALESCE(vn.ventas_net, 0) - ps.prod_total - COALESCE(p.costo_envio_domicilio,0), 2) gap
      FROM pedidos p
      JOIN (SELECT pedido_id,
                   SUM(IF(peso IS NULL, cantidad * precio_con_descuento,
                                         cantidad * peso * precio_con_descuento)) prod_total
            FROM productos_solicitados GROUP BY pedido_id) ps ON ps.pedido_id = p.id
      LEFT JOIN (SELECT c.pedido_id, SUM(IF(t.debitan = 1, c.total, -c.total)) ventas_net
                 FROM comprobantes c JOIN tipos_comprobantes t ON t.id = c.tipo_id
                 WHERE c.estado_id = 2 AND c.type LIKE 'Ventas::Facturacion::%'
                 GROUP BY c.pedido_id) vn ON vn.pedido_id = p.id
      WHERE p.estado_id IN (3, 4)
        AND ABS(COALESCE(vn.ventas_net, 0) - ps.prod_total - COALESCE(p.costo_envio_domicilio,0)) > 0.01
    SQL

    rows = ActiveRecord::Base.connection.exec_query(sql).to_a
    stamp.call("Found #{rows.size} residual pedidos")

    fixed = 0
    skipped = 0
    ActiveRecord::Base.transaction do
      rows.each do |row|
        pid = row['pedido_id']
        pedido = Pedidos::Pedido.find(pid)

        # Compute effective renglones from confirmed factura/NC
        cbtes = Comprobantes::Comprobante
                .where(pedido_id: pid, estado_id: 2)
                .where('type LIKE ?', 'Ventas::Facturacion::%')
                .includes(:tipo, :renglones)
                .to_a

        if cbtes.empty?
          stamp.call("SKIP pedido=#{pid} no confirmed comprobantes (gap=#{row['gap']})")
          skipped += 1
          next
        end

        # net qty/total per (producto_id, precio_unitario)
        effective = Hash.new(0.0) # key: [producto_id, precio_unitario] => cantidad
        cbtes.each do |c|
          sign = c.tipo.debitan ? 1 : -1
          c.renglones.each do |r|
            next if r.producto_id.nil?

            key = [r.producto_id, r.precio_unitario.to_f.round(6)]
            effective[key] += sign * r.cantidad.to_f
          end
        end

        # Build set of existing ps for this pedido (id => ps)
        existing_ps = pedido.productos_solicitados.to_a
        # Group existing ps by (producto_id, pcd)
        existing_by_key = existing_ps.group_by { |ps| [ps.producto_id, ps.precio_con_descuento.to_f.round(6)] }

        # Action plan
        actions = []

        effective.each do |(prod_id, pu), qty|
          qty = qty.round(6)
          next if qty.abs < 0.0001 # nets to zero

          matches = existing_by_key[[prod_id, pu]]
          if matches&.any?
            # Update the first match to qty, delete other matches
            first = matches.first
            actions << [:update_qty, first.id, qty] if (first.cantidad.to_f - qty).abs > 0.0001
            matches[1..].each { |ps| actions << [:delete_ps, ps.id] }
            existing_by_key.delete([prod_id, pu])
          else
            actions << [:create_ps, prod_id, pu, qty]
          end
        end

        # Any leftover existing ps not in effective → delete (those products were not billed)
        existing_by_key.each_value do |list|
          list.each { |ps| actions << [:delete_ps, ps.id] }
        end

        if actions.empty?
          stamp.call("NOOP pedido=#{pid} gap=#{row['gap']} (renglones match ps; gap may be pesable rounding)")
          skipped += 1
          next
        end

        stamp.call("FIX pedido=#{pid} gap=#{row['gap']} actions=#{actions.size}")

        next if dry_run

        actions.each do |act|
          case act[0]
          when :update_qty
            ps_id = act[1]
            qty = act[2]
            Productos::ProductoSolicitado.where(id: ps_id).update_all(cantidad: qty, peso: nil)
          when :delete_ps
            Productos::ProductoSolicitado.where(id: act[1]).delete_all
          when :create_ps
            prod_id = act[1]
            pu = act[2]
            qty = act[3]
            Productos::ProductoSolicitado.connection.execute(
              ActiveRecord::Base.send(:sanitize_sql_array, [
                                        'INSERT INTO productos_solicitados (pedido_id, producto_id, cantidad, ' \
                                        'precio_unitario, precio_con_descuento) VALUES (?, ?, ?, ?, ?)',
                                        pid, prod_id, qty, pu, pu
                                      ])
            )
          end
        end

        fixed += 1
      end
    end

    stamp.call("Done. fixed=#{fixed} skipped=#{skipped} dry_run=#{dry_run}")
  ensure
    log&.close
  end

  desc 'Print per-tienda pedido vs ventas gap.'
  task print_gap_summary: :environment do
    sql = <<~SQL.squish
      SELECT COALESCE(p.tienda_id, 'ALL') tienda,
             ROUND(SUM(ps.prod_total + p.costo_envio_domicilio), 2) pedidos_total
      FROM pedidos p
      JOIN (SELECT pedido_id,
                   SUM(IF(peso IS NULL, cantidad * precio_con_descuento,
                                         cantidad * peso * precio_con_descuento)) prod_total
            FROM productos_solicitados GROUP BY pedido_id) ps ON ps.pedido_id = p.id
      WHERE p.estado_id IN (3, 4)
      GROUP BY p.tienda_id WITH ROLLUP
    SQL
    pedidos = ActiveRecord::Base.connection.exec_query(sql).to_a.index_by { |r| r['tienda'].to_s }

    sql_v = <<~SQL.squish
      SELECT COALESCE(c.tienda_id, 'ALL') tienda,
             ROUND(SUM(IF(t.debitan = 1, c.total, -c.total)), 2) ventas_net
      FROM comprobantes c JOIN tipos_comprobantes t ON t.id = c.tipo_id
      WHERE c.estado_id = 2 AND c.type LIKE 'Ventas::Facturacion::%'
      GROUP BY c.tienda_id WITH ROLLUP
    SQL
    ventas = ActiveRecord::Base.connection.exec_query(sql_v).to_a.index_by { |r| r['tienda'].to_s }

    puts 'tienda              pedidos             ventas                gap'
    (pedidos.keys | ventas.keys).each do |k|
      p_t = pedidos[k]&.dig('pedidos_total').to_f
      v_t = ventas[k]&.dig('ventas_net').to_f
      puts format('%-8s %18.2f %18.2f %18.2f', k, p_t, v_t, v_t - p_t)
    end
  end

  desc 'Reprocess missed MercadoPago multi-pedido payments: reset failed DJs and re-enqueue for silently-skipped pedidos. DRY_RUN=1 (default).'
  task reprocess_missed_mp_payments: :environment do
    dry_run = ENV['DRY_RUN'] != '0'
    puts "=== reprocess_missed_mp_payments (dry_run=#{dry_run}) ==="
    puts Time.current

    # 1. Failed Delayed::Jobs from the pre-fix NoMethodError era
    failed_jobs = Delayed::Job
                  .where.not(failed_at: nil)
                  .where("handler LIKE '%MercadopagoUpdaterJob%'")
    puts "Failed DJ jobs to reset: #{failed_jobs.count}"

    failed_jobs.find_each do |job|
      puts "  #{dry_run ? 'DRY' : 'FIX'} reset DJ##{job.id} (attempts=#{job.attempts}, " \
           "error=#{job.last_error.to_s.first(120)})"
      next if dry_run

      job.update_columns(failed_at: nil, last_error: nil, attempts: 0, run_at: Time.current)
    end

    # 2. Silently-skipped pedidos: grupo pagado but pedidos still pendiente with products
    pagado_estado    = Pedidos::PedidoMultiple::ESTADOS[:pagado]
    not_done_estados = [3, 4, 5] # confirmado, finalizado, cancelado

    grupos_pagados = Pedidos::PedidoMultiple.where(estado: pagado_estado)
    puts "PedidoMultiple groups with estado=pagado: #{grupos_pagados.count}"

    enqueued = 0
    skipped  = 0

    grupos_pagados.includes(pedidos: :productos_solicitados).find_each do |grupo|
      pending_pedidos = grupo.pedidos.reject do |p|
        not_done_estados.include?(p.estado_id) || p.productos_solicitados.empty?
      end
      next if pending_pedidos.empty?

      pago = Ventas::Facturacion::PagoElectronico
             .where(pedido_multiple_id: grupo.id).where.not(pago_id: nil).first
      pago ||= Ventas::Facturacion::PagoElectronico
               .where(pedido_id: grupo.pedido_ids).where.not(pago_id: nil).first

      unless pago
        puts "  WARN: Grupo ##{grupo.id} has #{pending_pedidos.size} pending pedidos but no " \
             'PagoElectronico found — manual review needed'
        skipped += 1
        next
      end

      pending_ids = pending_pedidos.map(&:id).join(', ')
      puts "  #{dry_run ? 'DRY' : 'FIX'} re-enqueue grupo ##{grupo.id} pago_id=#{pago.pago_id} " \
           "(pending pedidos: #{pending_ids})"
      next if dry_run

      Pedidos::MercadopagoUpdaterJob.perform_later(pago.pago_id)
      enqueued += 1
    end

    puts '=== Summary ==='
    puts "Failed DJ jobs to reset:    #{failed_jobs.count}"
    puts "Groups re-enqueued:         #{enqueued}"
    puts "Groups without pago_id:     #{skipped} (manual review needed)"
  end
end
