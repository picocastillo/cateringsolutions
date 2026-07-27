module Pedidos
  class PedidosCocinaQuery < ApplicationQuery
    # Attributes for filtering
    attr_accessor :codigo, :estado_id, :fecha_desde, :fecha_hasta, :user, :autor_id, :tienda_id, :descripcion,
                  :usuario_ids, :cliente_ids, :cuenta_ids,
                  :horarios_de_corte_ids, :horario_corte_cliente_ids, :horario_corte_cuenta_ids

    # Date attributes
    attribute :fecha_desde, DateTime
    attribute :fecha_hasta, DateTime

    validates :user, presence: true

    def relation
      base_query.includes(:autor, :tienda,
                          pedidos: [{ cuenta: :cliente }, :usuario, :productos_solicitados]).order('pedidos_cocina.fecha desc, pedidos_cocina.codigo desc')
    end

    def base_query
      q = PedidoCocina.joins(:pedidos)

      # Filter by user's tienda_activa if user is present
      q = q.by_tienda(user.tienda_activa.id) if user.present?

      # Basic filters using scopes when available
      q = q.where(codigo: codigo) if codigo.present?
      q = q.by_estado(estado_id) if estado_id.present?
      q = q.where(autor_id: autor_id) if autor_id.present?
      q = q.by_tienda(tienda_id) if tienda_id.present?
      q = q.where('descripcion ILIKE ?', "%#{descripcion}%") if descripcion.present?

      # Date filters using scope
      if fecha_desde.present? && fecha_hasta.present?
        # Use range for better performance
        q = q.where(fecha: fecha_desde.to_datetime.beginning_of_day..fecha_hasta.to_datetime.end_of_day)
      elsif fecha_desde.present?
        q = q.where(pedidos_cocina: { fecha: fecha_desde.to_datetime.beginning_of_day.. })
      elsif fecha_hasta.present?
        q = q.where(fecha: ..fecha_hasta.to_datetime.end_of_day)
      end

      # User-specific filters
      # Internal users (employees) can filter by clients, accounts, or users
      q = q.joins(pedidos: { cuenta: :cliente }).where(clientes: { id: cliente_ids.split(',').map(&:to_i) }) if cliente_ids.present?

      q = q.where(pedidos: { cuenta_id: cuenta_ids.split(',').map(&:to_i) }) if cuenta_ids.present?

      q = q.where(pedidos: { usuario_id: usuario_ids.split(',').map(&:to_i) }) if usuario_ids.present?

      if horarios_de_corte_ids.present?
        hc_values = (horarios_de_corte_ids.is_a?(String) ? horarios_de_corte_ids.split(',') : horarios_de_corte_ids).compact_blank
        if hc_values.any?
          q = q.joins(pedidos: { cuenta: :cliente })
               .where("COALESCE(NULLIF(cuentas.horario_corte_pedidos, ''), clientes.horario_corte_pedidos) IN (?)", hc_values)
        end
      end
      if horario_corte_cliente_ids.present?
        hc_values = (horario_corte_cliente_ids.is_a?(String) ? horario_corte_cliente_ids.split(',') : horario_corte_cliente_ids).compact_blank
        q = q.joins(pedidos: { cuenta: :cliente }).where(clientes: { horario_corte_pedidos: hc_values }) if hc_values.any?
      end
      if horario_corte_cuenta_ids.present?
        hc_values = (horario_corte_cuenta_ids.is_a?(String) ? horario_corte_cuenta_ids.split(',') : horario_corte_cuenta_ids).compact_blank
        q = q.joins(pedidos: :cuenta).where(cuentas: { horario_corte_pedidos: hc_values }) if hc_values.any?
      end

      q.distinct
    end
  end
end
