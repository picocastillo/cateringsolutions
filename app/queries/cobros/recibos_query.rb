module Cobros
  class RecibosQuery < ApplicationQuery
    attr_accessor :nro, :estado, :user, :cuenta, :horarios_de_corte_ids

    attribute :emitidos_desde, Date, default: proc { 1.month.ago.to_date }
    attribute :emitidos_hasta, Date

    def relation
      q = Recibo.order(:nro).includes(:cuenta)
      q = q.where(tienda_id: user.tienda_activa.id)
      q = q.where(estado_id: estado) if estado.present?
      q = q.where(comprobantes: { local_id: user.local_activo.id }) if user.tienda_activa.multiple_locales && user.local_activo
      q = q.where(nro: nro) if nro.present?
      q = q.where(cuenta_id: cuenta) if cuenta.present?
      q = filtrar_x_horario_corte q
      filtrar_x_fecha q
    end

    private

    def filtrar_x_horario_corte(q)
      if horarios_de_corte_ids.present?
        hc_values = (horarios_de_corte_ids.is_a?(String) ? horarios_de_corte_ids.split(',') : horarios_de_corte_ids).compact_blank
        if hc_values.any?
          q = q.joins(cuenta: :cliente)
               .where("COALESCE(NULLIF(cuentas.horario_corte_pedidos, ''), clientes.horario_corte_pedidos) IN (?)", hc_values)
        end
      end
      q
    end

    def filtrar_x_fecha(q)
      q = q.emitidos_desde emitidos_desde if emitidos_desde.present?
      q = q.emitidos_hasta emitidos_hasta if emitidos_hasta.present?
      q
    end
  end
end
