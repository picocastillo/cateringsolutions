module Cupones
  class CuponesQuery < ApplicationQuery
    attr_accessor :user, :grupo, :codigo, :estado

    attribute :fecha_vencimiento_desde, Date
    attribute :fecha_vencimiento_hasta, Date

    def relation
      q = Cupon.order(created_at: :desc)
      q = q.where(tienda_id: user.tienda_activa.id)
      q = q.where('grupo LIKE ?', "#{grupo.strip}%") if grupo.present?
      q = q.where(codigo: codigo.strip.upcase) if codigo.present?
      q = filtrar_x_estado q
      filtrar_x_fecha_vencimiento q
    end

    private

    def filtrar_x_estado(q)
      return q if estado.blank?

      case estado
      when 'vigente'
        q.vigentes
      when 'usado'
        q.where(id: Pedidos::Pedido.where.not(cupon_id: nil).select(:cupon_id))
      when 'cancelado'
        q.where(cancelado: true)
      when 'vencido'
        q.no_usados.where(cancelado: false).where(fecha_vencimiento: ...Date.current)
      else
        q
      end
    end

    def filtrar_x_fecha_vencimiento(q)
      q = q.where(fecha_vencimiento: fecha_vencimiento_desde..) if fecha_vencimiento_desde.present?
      q = q.where(fecha_vencimiento: ..fecha_vencimiento_hasta) if fecha_vencimiento_hasta.present?
      q
    end
  end
end
