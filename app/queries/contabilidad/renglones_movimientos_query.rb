module Contabilidad
  class RenglonesMovimientosQuery < MovimientosQuery
    attribute :condicion_eq, String, default: 'Pendientes'
    attribute :de_cliente, Integer
    attribute :para_pdf, Boolean

    validate :filtros_correctos, if: :para_pdf?

    def relation
      q = super.joins(:comprobante).order('cuentas.nro, indice')
      q = q.where('saldo <> 0') if condicion_eq.present?
      q = q.joins(:comprobante).where(comprobantes: { fecha_vencimiento: ...Time.zone.today }) if condicion_eq == 'Vencidos'
      q = q.joins(:comprobante).where(comprobantes: { fecha_vencimiento: Time.zone.today.. }) if condicion_eq == 'A Vencer'
      q = q.joins(:cuenta).where('cuentas.cliente_id in(?)', de_cliente) if de_cliente.present?
      q
    end

    def movimientos_con_saldos(pagina = nil, limite = nil)
      return if invalid?

      movs = relation.preload(:imputado, cuenta: :cliente,
                                         comprobante: { pedido: [:usuario, { cuenta: :cliente }] })
      movs = movs.page(pagina.presence || 1)
      movs = movs.per_page(limite) if limite.present?
      movs_array = movs.to_a
      saldos = calcular_saldos_anteriores(movs_array)
      saldo_anterior = saldos[movs_array.first&.cuenta_id] || 0
      (movs + [nil]).each_cons(2) do |mov, sig|
        mov.condicion = condicion_eq
        saldo_anterior += mov.importe_condicionado
        mov.saldo_cuenta = saldo_anterior
        saldo_anterior = saldos[sig.cuenta_id] || 0 if sig && mov.cuenta != sig.cuenta
      end
      movs
    end

    def calcular_saldos_anteriores(movs_array)
      return {} if movs_array.empty?

      primeros_por_cuenta = {}
      movs_array.each do |mov|
        next if primeros_por_cuenta.key?(mov.cuenta_id)

        primeros_por_cuenta[mov.cuenta_id] = mov.indice
      end
      return {} if primeros_por_cuenta.empty?

      copia_desde = desde
      copia_hasta = hasta
      self.desde = nil
      self.hasta = nil

      sum_col = condicion_eq.present? ? 'saldo' : 'importe'

      conditions = primeros_por_cuenta.map do |cuenta_id, indice|
        Movimiento.sanitize_sql_array(
          ['(movimientos_cbles.cuenta_id = ? AND movimientos_cbles.indice < ?)', cuenta_id, indice]
        )
      end

      results = relation.where(conditions.join(' OR '))
                        .group('movimientos_cbles.cuenta_id')
                        .sum(sum_col)

      self.desde = copia_desde
      self.hasta = copia_hasta

      results
    end

    def rango_fecha_amplio?
      return false if condicion_eq.present?
      return true if desde.blank?

      h = hasta.present? ? hasta.to_date : Date.new
      d = desde.to_date
      meses = ((h.year * 12) + h.month) - ((d.year * 12) + d.month)
      meses > 6
    end

    private

    def filtros_correctos
      if rango_fecha_amplio?
        raise ErrorAplicacion,
              "No se permiten crear PDFs con rangos de fecha mayores a 6 meses y la condición es 'Todos' activada."
      end
      if user.admin_complejo? && user.de_cc? && clientes_ids.blank? &&
         cuentas_ids.blank? && cuit.blank? && zona_id.blank?
        raise ErrorAplicacion,
              'No se permiten crear PDFs tan extensos, utilize un filtro por favor.'
      end
    end
  end
end
