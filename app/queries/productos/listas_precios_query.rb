module Productos
  class ListasPreciosQuery < ApplicationQuery
    attr_accessor :clientes_ids, :categoria_ids, :nombre_producto, :status, :solo_duplicados, :fechas_invalidas, :productos_sin_precio, :importe_min,
                  :importe_max, :user

    attribute :activo_el, Date, default: proc { Time.zone.today }

    def relation
      q = base_scope

      if solo_duplicados.present? && solo_duplicados.to_s.in?(['true', '1'])
        dup_ids = compute_duplicate_ids(base_scope)
        return q.none if dup_ids.empty?

        q = q.where(precios: { id: dup_ids })
             .reorder(Arel.sql('productos.nombre ASC, precios.fecha_desde ASC, precios.fecha_hasta ASC, MAX(cp_order.cliente_id) ASC'))
      end

      if fechas_invalidas.present? && fechas_invalidas.to_s.in?(['true', '1'])
        q = q.where(
          '(precios.fecha_desde IS NOT NULL AND precios.fecha_hasta IS NOT NULL AND precios.fecha_desde > precios.fecha_hasta) ' \
          'OR (precios.fecha_hasta IS NULL) ' \
          'OR (precios.fecha_desde IS NULL AND precios.fecha_hasta IS NULL)'
        )
      end

      q
    end

    def productos_sin_precio?
      productos_sin_precio.present? && productos_sin_precio.to_s.in?(['true', '1'])
    end

    def productos_sin_precio_query
      fecha = activo_el || Time.zone.today
      q = Productos::Producto.active
                             .where(tienda_id: user.tienda_activa.id)
                             .where.not(
                               id: Productos::Precio.select(:producto_id)
                                   .where('precios.fecha_desde <= ? AND (precios.fecha_hasta >= ? OR precios.fecha_hasta IS NULL)', fecha, fecha)
                             )
                             .includes(:categoria)
                             .order(:nombre)

      if categoria_ids.present?
        ids = (categoria_ids.is_a?(String) ? categoria_ids.split(',') : categoria_ids).compact_blank
        q = q.where(categoria_id: ids) if ids.any?
      end

      q = q.where('productos.nombre LIKE ?', "%#{nombre_producto}%") if nombre_producto.present?

      q
    end

    def duplicate_precio_ids
      @duplicate_precio_ids ||= compute_duplicate_ids(base_scope)
    end

    # Returns a hash mapping each duplicate precio_id to a group index (for coloring)
    def duplicate_groups
      @duplicate_groups ||= begin
        precios = precios_for_dup_check
        groups = precios.group_by do |p|
          [p.producto_id, p.importe.to_d, p.clientes.map(&:id).sort, p.fecha_desde, p.fecha_hasta]
        end
        result = {}
        color_index = 0
        groups.each_value do |v|
          next unless v.size > 1

          v.each { |p| result[p.id] = color_index }
          color_index += 1
        end
        result
      end
    end

    private

    def base_scope
      q = Productos::Precio.joins(:producto)
                           .joins('LEFT JOIN clientes_precios cp_order ON cp_order.precio_id = precios.id')
                           .where(productos: { tienda_id: user.tienda_activa.id })
                           .includes(:clientes, producto: :categoria)
                           .group('precios.id')
                           .order(Arel.sql('productos.nombre ASC, MAX(cp_order.cliente_id) IS NULL ASC, precios.fecha_desde ASC'))

      q = q.status(status) if status.present?

      if clientes_ids.present?
        ids = (clientes_ids.is_a?(String) ? clientes_ids.split(',') : clientes_ids).compact_blank
        if ids.any?
          q = q.joins('LEFT JOIN clientes_precios cp_filter ON cp_filter.precio_id = precios.id')
               .where('cp_filter.cliente_id IN (?) OR cp_filter.cliente_id IS NULL', ids)
        end
      end

      if categoria_ids.present?
        ids = (categoria_ids.is_a?(String) ? categoria_ids.split(',') : categoria_ids).compact_blank
        q = q.where(productos: { categoria_id: ids }) if ids.any?
      end

      q = q.where('productos.nombre LIKE ?', "%#{nombre_producto}%") if nombre_producto.present?

      q = q.where(precios: { importe: importe_min.. }) if importe_min.present?
      q = q.where(precios: { importe: ..importe_max }) if importe_max.present?

      if activo_el.present?
        q = q.where('precios.fecha_desde <= ? AND (precios.fecha_hasta >= ? OR precios.fecha_hasta IS NULL)',
                    activo_el, activo_el)
      end

      q
    end

    def compute_duplicate_ids(scope)
      precios = precios_for_dup_check(scope)

      groups = precios.group_by do |p|
        [p.producto_id, p.importe.to_d, p.clientes.map(&:id).sort, p.fecha_desde, p.fecha_hasta]
      end

      groups.select { |_, v| v.size > 1 }.values.flatten.to_set(&:id)
    end

    # Reload precios via a clean (no group/no extra joins) scope so that
    # `.includes(:clientes)` populates the HABTM collection correctly.
    # Doing `.includes(:clientes)` on `base_scope` directly is unsafe — the
    # base scope has `.group('precios.id')` + a LEFT JOIN to `clientes_precios`
    # and Rails can return precios with empty/wrong `clientes` collections,
    # which makes universal precios collide with client-specific ones in the
    # in-memory grouping (and the action then deletes the wrong row).
    def precios_for_dup_check(scope = base_scope)
      ids = scope.reorder('').pluck(Arel.sql('precios.id'))
      Productos::Precio
        .where(id: ids)
        .includes(:clientes)
        .to_a
    end
  end
end
