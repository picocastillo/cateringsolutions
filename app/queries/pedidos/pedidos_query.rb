module Pedidos
  class PedidosQuery < ApplicationQuery
    attr_accessor :codigo, :estado_id, :user, :cliente_ids, :mercado_pago_id, :usuario_ids,
                  :producto_ids, :cuentas_ids, :enviar_a_id, :autor_id, :carga_simple, :para, :no_pendientes, :cargado_por_id, :sin_pedido_cocina, :horario_ids,
                  :horarios_de_corte_ids, :horario_corte_cliente_ids, :horario_corte_cuenta_ids, :venta_mostrador, :descuento_venta_mostrador_id

    attribute :fecha_desde, Date
    attribute :fecha_hasta, Date

    def relation
      q = base_query.includes(productos_solicitados: { producto: :categoria },
                              cuenta: :cliente, autor: [cuenta: :cliente])
      q = q.group('pedidos.id') if productos.present?
      q.order('pedidos.fecha desc, pedidos.codigo desc')
    end

    def base_query
      q = user&.cliente? ? Pedido.order('pedidos.fecha desc') : Pedido.order(nil)
      # Step 5 of shared-clientes migration: cliente users see THEIR pedidos
      # across every tienda their cliente is linked to. The
      # `pedidos.usuario_id = user.id` / `cliente_id = user.cliente.id` clauses
      # below already scope the rows correctly, so we only restrict by tienda
      # for non-cliente (admin/operador) users.
      q = q.where(tienda_id: user.tienda_activa) unless user&.cliente?
      q = q.where(codigo: codigo) if codigo.present?
      q = q.where(pedido_cocina_id: nil) if sin_pedido_cocina.present?
      q = q.where(horario_id: horario_ids) if horario_ids&.reject(&:blank?).present?
      q = q.where(pedidos: { local_id: user.local_activo.id }) if user.tienda_activa.multiple_locales && user.local_activo
      if mercado_pago_id.present?
        q = if mercado_pago_id == '1'
              q.joins('INNER JOIN pagos_electronicos mp ON mp.pedido_id = pedidos.id')
            else
              q.joins('LEFT JOIN pagos_electronicos mp ON mp.pedido_id = pedidos.id').where(mp: { id: nil })
            end
      end
      if !user.cliente?
        q = q.where(estado_id: estado_id) if estado_id.present?
        if cargado_por_id.present?
          q = if cargado_por_id == '1'
                q.joins('join usuarios autores on autores.id=pedidos.autor_id').where(autores: { cuenta_id: nil })
              else
                q.joins('join usuarios autores on autores.id=pedidos.autor_id').where.not(autores: { cuenta_id: nil })
              end
        end
      elsif estado_id.present?
        q = q.where(estado_id: estado_id)
      end
      q = q.where('pedidos.estado_id <> 1') if no_pendientes.present? && no_pendientes
      q = q.joins('join usuarios autores on autores.id=pedidos.autor_id').where(autores: { cuenta_id: nil }) if carga_simple.present? && carga_simple == true
      q = q.where(autor_id: autor_id) if autor_id.present?
      if enviar_a_id.present?
        q = q.where('pedidos.envio_a_domicilio = true') if enviar_a_id.to_i == 1
        q = q.where('pedidos.envio_a_domicilio = false') if enviar_a_id.to_i == 2
      end
      q = q.fecha_desde(fecha_desde) if fecha_desde.present?
      q = q.fecha_hasta(fecha_hasta) if fecha_hasta.present?
      if user.cliente?
        if user.cumple_rol?(:administrador_empresa)
          q = q.joins(:cuenta).where(cuentas: { cliente_id: user.cuenta.cliente })
          q = q.joins(:cuenta).where(pedidos: { cuenta_id: cuentas_ids.split(',').map(&:to_i) }) if cuentas_ids.present?
          q = q.joins(:usuario).where(usuarios: { id: usuario_ids.split(',').map(&:to_i) }) if usuario_ids.present?
        else
          q = q.where('pedidos.usuario_id =?', user.id)
        end
      else
        q = q.joins(:cuenta).where(cuentas: { cliente_id: cliente_ids.split(',').map(&:to_i) }) if cliente_ids.present?
        q = q.joins(:cuenta).where(pedidos: { cuenta_id: cuentas_ids.split(',').map(&:to_i) }) if cuentas_ids.present?
        q = q.joins(:usuario).where(usuarios: { id: usuario_ids.split(',').map(&:to_i) }) if usuario_ids.present?
      end
      q = q.where('(pedidos.autor_id = ? and pedidos.estado_id = 1) or (pedidos.estado_id <> 1)', user.id)
      if para.present?
        q = q.joins('left join usuarios on usuarios.id=pedidos.usuario_id')
        textos = para.to_s.upcase.split.compact_blank
        params = {}
        if textos.present?
          where_string = [
            where_string, textos.map.with_index do |_, i|
                            "usuarios.nombre like :texto_#{i} or pedidos.para like :texto_#{i}"
                          end.join(' and ')
          ].compact_blank.join(' or ')
          textos.each.with_index { |t, i| params[:"texto_#{i}"] = "%#{t}%" }
        end
        q = q.where where_string, params
      end
      cuentas_auxs = []
      cuentas_auxs = user.cuenta.cliente.cuentas.map(&:id) if !user.admin? && user.cumple_rol?(:administrador_empresa)
      q = q.where(pedidos: { cuenta_id: cuentas_auxs }) if cuentas_auxs.present?
      if productos.present?
        q = q.joins(:productos_solicitados)
        q = q.where(productos_solicitados: { producto_id: productos.map(&:id) })
      end
      if horarios_de_corte_ids.present?
        hc_values = (horarios_de_corte_ids.is_a?(String) ? horarios_de_corte_ids.split(',') : horarios_de_corte_ids).compact_blank
        if hc_values.any?
          q = q.joins(cuenta: :cliente)
               .where("COALESCE(NULLIF(cuentas.horario_corte_pedidos, ''), clientes.horario_corte_pedidos) IN (?)", hc_values)
        end
      end
      if horario_corte_cliente_ids.present?
        hc_values = (horario_corte_cliente_ids.is_a?(String) ? horario_corte_cliente_ids.split(',') : horario_corte_cliente_ids).compact_blank
        q = q.joins(cuenta: :cliente).where(clientes: { horario_corte_pedidos: hc_values }) if hc_values.any?
      end
      if horario_corte_cuenta_ids.present?
        hc_values = (horario_corte_cuenta_ids.is_a?(String) ? horario_corte_cuenta_ids.split(',') : horario_corte_cuenta_ids).compact_blank
        q = q.joins(:cuenta).where(cuentas: { horario_corte_pedidos: hc_values }) if hc_values.any?
      end
      q = q.where(venta_mostrador: venta_mostrador == 'true') if venta_mostrador.present?
      if descuento_venta_mostrador_id.present?
        q = if descuento_venta_mostrador_id == 'any'
              q.where.not(descuento_venta_mostrador_id: nil)
            else
              q.where(descuento_venta_mostrador_id: descuento_venta_mostrador_id)
            end
      end
      q
    end

    def productos
      @productos ||= producto_ids.present? ? Productos::Producto.where(id: producto_ids.to_s.split(',')) : []
    end

    def footer_aggregates
      @footer_aggregates ||= begin
        row = base_query.joins(:productos_solicitados).pick(
          Arel.sql('COUNT(DISTINCT pedidos.id)'),
          Arel.sql('SUM(productos_solicitados.cantidad)'),
          Arel.sql('SUM(CASE WHEN pedidos.estado_id <> 5 ' \
                   'THEN COALESCE(productos_solicitados.precio_con_descuento, productos_solicitados.precio_unitario) * productos_solicitados.cantidad * COALESCE(productos_solicitados.peso, 1) ' \
                   'ELSE 0 END)')
        )
        # costo_envio_domicilio must be summed in a separate query scoped to the same
        # pedidos. Including it inside the SUM(CASE...) above multiplies it by the
        # number of productos_solicitados rows per pedido instead of counting it once.
        envio = Pedidos::Pedido
                .where(id: base_query.where('pedidos.estado_id <> 5').select('pedidos.id'))
                .sum(:costo_envio_domicilio)
        { pedidos_count: row[0].to_i, cantidad_total: row[1].to_i, importe_total: row[2].to_f + envio.to_f }
      end
    end

    private

    def cuentas
      return if cuentas_ids.blank?

      Clientes::Cuenta.where(id: cuentas_ids.to_s.split(','))
    end
  end
end
