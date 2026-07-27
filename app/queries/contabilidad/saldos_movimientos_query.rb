module Contabilidad
  class SaldosMovimientosQuery < MovimientosQuery
    attribute :csv_dias_numericos, String, default: nil

    def relation
      self.visualizar_por_id = 3 if usuarios_ids.present?
      q = super.order('cuentas.nro').select ['movimientos_cbles.*', 'sum(case when movimientos_cbles.saldo < 0 then saldo*-1 else 0 end) as saldo_favor',
                                             'sum(case when movimientos_cbles.saldo <> 0 then saldo else 0 end) as saldo_total']
      q = q.select select_vencimientos_a_dias if csv_dias_numericos.present?
      q = q.joins(comprobante: :pedido) if csv_dias_numericos.present?
      agrupar q.where('saldo <> 0')
    end

    def agrupar(q)
      q = q.group('cuentas.cliente_id') if visualizar_por_id.blank? || visualizar_por_id.to_i == 1
      q = q.group('cuentas.cliente_id, cuentas.id') if visualizar_por_id.to_i == 2
      q = q.joins(comprobante: :pedido).group('cuentas.cliente_id, cuentas.id, pedidos.usuario_id') if visualizar_por_id.to_i == 3
      q
    end

    def headers_de_vencimiento
      columnas = []
      return columnas if fechas.blank?

      ([nil] + fechas + [nil]).each_cons(2).with_index.map do |(d1, d2), i|
        columnas << if d1 && d2
                      ["saldo_#{i}",
                       (d2 < DateTime.current.to_date ? "Vencidos al #{d2.to_date}" : "A vencer al #{d2.to_date}")]
                    else
                      ["saldo_#{i}", (d1 ? "A vencer + del #{d1.to_date}" : "Anterior al #{d2.to_date}")]
                    end
      end
      columnas
    end
    memoize :headers_de_vencimiento

    def select_vencimientos_a_dias
      return [] if fechas.blank?

      ([nil] + fechas + [nil]).each_cons(2).with_index.map do |(d1, d2), i|
        cond_fecha = []
        cond_fecha << "comprobantes.fecha_vencimiento >= '#{d1.to_fs(:db)}'" if d1
        condicion_2 = d2 ? "<'#{d2.to_fs(:db)}'" : ">= '#{d1.to_fs(:db)}'"
        cond_fecha << "comprobantes.fecha_vencimiento #{condicion_2}"
        "sum(case when #{cond_fecha.join(' and ')} and movimientos_cbles.saldo != 0 then saldo else 0 end) as saldo_#{i}"
      end
    end

    def csv_dias_numericos=(dias)
      @csv_dias_numericos = dias.split(',').map { |d| d.strip.to_i }.sort.join(', ')
    end

    def valido_para_pdf?
      fechas.count.to_i < 6
    end

    def totales
      relation.unscope!(:group).first
    end

    private

    def fechas
      csv_dias_numericos.to_s.split(',').map(&:to_i).map { |dia| dia.days.since.to_date }
    end
    memoize :fechas
  end
end
