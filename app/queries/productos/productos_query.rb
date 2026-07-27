module Productos
  class ProductosQuery < ApplicationQuery
    attr_accessor :nombre, :descripcion, :status, :categoria_ids, :codigo, :clientes_ids, :codigo_externo, :user,
                  :busqueda, :producto_id, :cantidad, :dias_vencimiento, :pesable

    attribute :activo_el, Date

    def relation
      q = Producto.order(:nombre).group('productos.id').status(status)
      q = q.where(tienda_id: user.tienda_activa)
      q = q.where('productos.nombre like ?', "%#{nombre}%") if nombre.present?
      q = q.where('productos.descripcion like ?', "%#{descripcion}%") if descripcion.present?
      q = q.where('productos.codigo like ?', codigo) if codigo.present?
      if codigo_externo.present?
        q = q.where('productos.codigos_externos rlike ?',
                    "(^|,\s?)#{Regexp.quote codigo_externo.to_s}($|,\s?)")
      end
      if clientes_ids.present?
        pj = true
        q = q.joins('join precios p on p.producto_id=productos.id left join clientes_precios cp on cp.precio_id=p.id')
        q = q.where(
          '(cp.cliente_id in (?) or cp.cliente_id is null) ' \
          'and (p.fecha_desde <= ? and (p.fecha_hasta >= ? or p.fecha_hasta is null))',
          clientes_ids, Time.zone.today, Time.zone.today
        )
      end
      if activo_el.present?
        q = q.joins('join precios p on p.producto_id=productos.id left join clientes_precios cp on cp.precio_id=p.id') unless pj
        q = q.where('(p.fecha_desde <= ? and (p.fecha_hasta >= ? or p.fecha_hasta is null))', activo_el, activo_el)
      end
      if busqueda.present?
        params = {}
        where_string = ''
        if (textos = busqueda.to_s.split.compact_blank).present?
          where_string = [
            where_string, textos.map.with_index do |_, i|
                            "productos.nombre like :texto_#{i}"
                          end.join(' and '), textos.map.with_index do |_, i|
                                               "productos.codigo like :texto_#{i}"
                                             end.join(' and '),
            textos.map.with_index { |_, i| "productos.codigos_externos like :texto_#{i}" }.join(' and ')
          ].compact_blank.join(' or ')
          textos.each.with_index { |t, i| params[:"texto_#{i}"] = "%#{t}%" }
        end
        q = q.where where_string, params
      end
      q = q.where(categoria_id: categoria_ids) if categoria_ids.present?
      q = q.where(pesable: pesable == 'true') if pesable.present?
      q
    end
  end
end
