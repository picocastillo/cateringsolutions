module Ventas
  module Facturacion
    class ComprobantesQuery < ApplicationQuery
      extend Memoist

      attr_accessor :user, :clientes_ids, :estado_id, :tipo_id, :nro, :categoria_id, :autor, :cuenta_ids, :horarios_de_corte_ids, *Renglon::Scopes

      attribute :emitidos_desde, Date
      attribute :emitidos_hasta, Date
      attribute :pedido_desde, Date
      attribute :pedido_hasta, Date

      validates :emitidos_desde, :emitidos_hasta, :pedido_desde, :pedido_hasta, date: true, allow_nil: true

      def relation
        q = Comprobante.order 'comprobantes.fecha_emision desc'
        q = filtrar_x_fecha q
        q = q.joins(:autor).merge User.by_login_or_nombre autor if autor.present?
        q = filtrar_renglones q
        q = q.where('nro like ?', nro.to_i) if nro.present?
        q = q.where(estado_id: estado_id.to_i) if estado_id.present?
        q = q.where(tipo_id: tipo_id.to_i) if tipo_id.present?
        q = q.where(comprobantes: { local_id: user.local_activo.id }) if user.tienda_activa.multiple_locales && user.local_activo
        q = filtrar_x_pedido q
        q = q.joins(:cuenta).where('cuentas.cliente_id in(?)', clientes.map(&:id)) if clientes.present?
        q = q.where('comprobantes.cuenta_id in(?)', cuenta_ids) if cuenta_ids.present?
        q = filtrar_x_horario_corte q
        q.where(tienda_id: user.tienda_activa)
      end

      def clientes
        return if clientes_ids.blank?

        Clientes::Cliente.disponibles_en(user.tienda_activa).where(id: clientes_ids.to_s.split(','))
      end
      memoize :clientes

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

      def filtrar_renglones(q)
        Renglon::Scopes.each do |sr|
          q = q.group(:id).joins(:renglones).merge Renglon.send sr, send(sr) if send(sr).present?
        end
        q
      end

      def filtrar_x_pedido(q)
        q = q.joins(:pedido).merge Pedidos::Pedido.fecha_desde(pedido_desde) if pedido_desde.present?
        q = q.joins(:pedido).merge Pedidos::Pedido.fecha_hasta(pedido_hasta) if pedido_hasta.present?
        q
      end
    end
  end
end
