module Productos
  class ProductosSolicitadosQuery < ApplicationQuery
    attr_accessor :fecha, :user, :codigo, :estado_id, :fecha_desde, :fecha_hasta, :cliente_ids, :cuentas_ids,
                  :usuario_ids, :fecha_obligatoria, :ver_aceptados_etiquetas, :horario_ids, :categoria_ids, :horarios_de_corte_ids, :pedido_cocina_id,
                  :horario_corte_cliente_ids, :horario_corte_cuenta_ids, :venta_mostrador, :local_id

    attribute :agrupar_por_id, Integer, default: 2
    validate :fecha_presente

    validates :fecha, date: true, allow_nil: true
    validates :fecha_desde, date: true, allow_nil: true
    validates :fecha_hasta, date: true, allow_nil: true

    def relation
      q = base_query
      q.group(:producto_id).select(
        'productos_solicitados.*, sum(COALESCE(precio_con_descuento, productos_solicitados.precio_unitario) * cantidad * COALESCE(productos_solicitados.peso, 1)) total_sumado, ' \
        'sum(cantidad) cantidad_sumada, ' \
        'sum(if(pedidos.estado_id = 2, cantidad, 0)) cantidad_aceptada, ' \
        'sum(if(pedidos.estado_id = 3, cantidad, 0)) cantidad_confirmada'
      )
    end

    def relation_por_medio_pago
      q = base_query
      q.group(:producto_id).select(
        'productos_solicitados.*, ' \
        'sum(COALESCE(precio_con_descuento, productos_solicitados.precio_unitario) * cantidad * COALESCE(productos_solicitados.peso, 1)) total_sumado, ' \
        'sum(cantidad) cantidad_sumada, ' \
        'sum(if(pedidos.estado_id = 2, cantidad, 0)) cantidad_aceptada, ' \
        'sum(if(pedidos.estado_id = 3, cantidad, 0)) cantidad_confirmada'
      )
    end

    def subtotales_por_medio_pago
      pedido_ids = base_query.select('DISTINCT pedidos.id')
      Pedidos::MedioPago
        .where(pedido_id: pedido_ids)
        .group(:tipo)
        .pluck(Arel.sql('tipo, SUM(importe)'))
        .map { |tipo, importe| [tipo, importe.to_f] }
    end

    def base_query
      q = ProductoSolicitado.joins(:pedido).where('pedidos.estado_id <> 1 and pedidos.estado_id <> 5')
      q = q.where(pedidos: { pedido_cocina_id: pedido_cocina_id.to_i }) if pedido_cocina_id.present?
      q = q.where(pedidos: { codigo: codigo }) if codigo.present?
      q = q.where(pedidos: { tienda_id: user.tienda_activa }) if user.tienda_activa.present?
      q = q.where(pedidos: { horario_id: horario_ids.map(&:to_i) }) if horario_ids.present?
      if local_id.present?
        q = q.where(pedidos: { local_id: local_id })
      elsif user.tienda_activa.multiple_locales && user.local_activo
        q = q.where(pedidos: { local_id: user.local_activo.id })
      end
      if ver_aceptados_etiquetas.present?
        q = if ver_aceptados_etiquetas == 'true'
              q.where('pedidos.estado_id in (3,2)')
            else
              q.where('pedidos.estado_id = 3')
            end
      elsif estado_id.present?
        q = q.where(pedidos: { estado_id: estado_id })
      end
      q = q.where(pedidos: { fecha: fecha_desde.to_date.. }) if fecha_desde.present?
      q = q.where(pedidos: { fecha: ..fecha_hasta.to_date }) if fecha_hasta.present?
      if user.cliente?
        if user.cumple_rol?(:administrador_empresa)
          q = q.joins(:pedido).where(pedidos: { cuenta_id: user.cuenta.cliente.cuentas.map(&:id) })
          q = q.joins(pedido: :usuario).where(usuarios: { id: usuario_ids }) if usuario_ids.present?
          q = q.joins(:pedido).where(pedidos: { cuenta_id: ctas_id }) if cuentas_ids.present?
        else
          q = q.where('pedidos.usuario_id =?', user)
        end
      else
        if cliente_ids.present?
          q = q.joins(:pedido).where(pedidos: { cuenta_id: Clientes::Cliente.where(id: cliente_ids.split(',').map(&:to_i)).to_a.flat_map do |x|
            x.cuentas.map(&:id)
          end })
        end
        q = q.joins(:pedido).where(pedidos: { cuenta_id: ctas_id }) if cuentas_ids.present?
        q = q.joins(pedido: :usuario).where(usuarios: { id: usuario_ids.split(',').map(&:to_i) }) if usuario_ids.present?
      end
      if horarios_de_corte_ids.present?
        hc_values = (horarios_de_corte_ids.is_a?(String) ? horarios_de_corte_ids.split(',') : horarios_de_corte_ids).compact_blank
        if hc_values.any?
          q = q.joins(pedido: { cuenta: :cliente })
               .where("COALESCE(NULLIF(cuentas.horario_corte_pedidos, ''), clientes.horario_corte_pedidos) IN (?)", hc_values)
        end
      end
      if horario_corte_cliente_ids.present?
        hc_values = (horario_corte_cliente_ids.is_a?(String) ? horario_corte_cliente_ids.split(',') : horario_corte_cliente_ids).compact_blank
        q = q.joins(pedido: { cuenta: :cliente }).where(clientes: { horario_corte_pedidos: hc_values }) if hc_values.any?
      end
      if horario_corte_cuenta_ids.present?
        hc_values = (horario_corte_cuenta_ids.is_a?(String) ? horario_corte_cuenta_ids.split(',') : horario_corte_cuenta_ids).compact_blank
        q = q.joins(pedido: :cuenta).where(cuentas: { horario_corte_pedidos: hc_values }) if hc_values.any?
      end
      q = q.where(pedidos: { fecha: fecha.to_date }) if fecha.present?
      q = q.joins(:producto).where(productos: { categoria_id: categoria_ids }) if categoria_ids.present?
      q = q.where(pedidos: { venta_mostrador: venta_mostrador == 'true' }) unless venta_mostrador.nil?
      q
    end

    def ctas_id
      ids = [user.cuenta_id].compact
      if cuentas_ids.present?
        if user.cliente?
          if user.cumple_rol?(:administrador_empresa)
            ctas = cuentas_ids.split(',').map(&:to_i)
            ids = ctas.select { |x| user.cuenta.cliente.cuentas.map(&:id).include?(x) }
          else
            ids = [user.cuenta].compact
          end
        else
          ids = cuentas_ids.split(',').map(&:to_i)
        end
      end
      ids.uniq
    end

    def crear_grupos(q)
      q = q.group('productos_solicitados.producto_id', 'pedidos.cuenta_id', 'pedidos.direccion_envio') if agrupar_por_id == 1
      if agrupar_por_id > 1
        q = q.group(['productos_solicitados.producto_id', 'pedidos.cuenta_id', 'pedidos.usuario_id',
                     'pedidos.direccion_envio'])
      end
      q
    end

    def clientes_lista
      scope = Clientes::Cliente.active.disponibles_en(user.tienda_activa).order(:nombre)
      scope = scope.where(id: cliente_ids.split(',').map(&:to_i)) if cliente_ids.present?
      scope
    end

    def clientes_lista_resumida
      if cliente_ids.present?
        Clientes::Cliente.active.where(id: cliente_ids.split(',').map(&:to_i)).order(:nombre)
      else
        ['Todos']
      end
    end

    def fecha_como_date
      fecha.presence&.to_date
    end

    def footer_aggregates
      @footer_aggregates ||= begin
        row = base_query.pick(
          Arel.sql('SUM(cantidad)'),
          Arel.sql('SUM(IF(pedidos.estado_id = 2, cantidad, 0))'),
          Arel.sql('SUM(IF(pedidos.estado_id = 3, cantidad, 0))'),
          Arel.sql('SUM(cantidad * COALESCE(precio_con_descuento, productos_solicitados.precio_unitario) * COALESCE(productos_solicitados.peso, 1))'),
          Arel.sql('SUM(IF(pedidos.estado_id = 2 AND pedidos.pedido_cocina_id IS NULL, cantidad, 0))'),
          Arel.sql('SUM(IF(pedidos.estado_id = 3 AND pedidos.pedido_cocina_id IS NULL, cantidad, 0))'),
          Arel.sql('SUM(IF(pedidos.estado_id = 3 AND pedidos.pedido_cocina_id IS NOT NULL, cantidad, 0))')
        ) || Array.new(7, 0)
        {
          cantidad_total: row[0].to_i,
          cantidad_aceptada: row[1].to_i,
          cantidad_confirmada: row[2].to_i,
          importe_total: row[3].to_f,
          pendientes: row[4].to_i,
          esperando: row[5].to_i,
          cocinando: row[6].to_i
        }
      end
    end

    private

    def fecha_presente
      return if fecha_obligatoria.blank?

      return if fecha.present? || (fecha_desde.present? && fecha_hasta.present?)

      errors.add :base,
                 'Debe ingresar una Fecha Desde y Fecha Hasta para la búsqueda.'
    end
  end
end
