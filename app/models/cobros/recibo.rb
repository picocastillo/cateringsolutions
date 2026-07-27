module Cobros
  class Recibo < Logistica::Flujos::FlujoEconomico
    def preparar_afectaciones
      total_cobrado = medios_pago.map(&:importe).sum
      total_sin_afectar = total_cobrado
      Ventas::Facturacion::Comprobante.pendientes_para_afectar(cuenta).includes(:tipo,
                                                                                cuenta: [:cliente]).find_each do |c|
        existente = afectaciones.detect { |a| a.afectado == c }
        if !existente
          if total_sin_afectar > c.saldo
            afectaciones.build afectado: c, importe: c.saldo
            total_sin_afectar -= c.saldo
          else
            afectaciones.build afectado: c, importe: total_sin_afectar
            total_sin_afectar = 0
          end
        elsif total_sin_afectar > c.saldo
          existente.importe = c.saldo
          total_sin_afectar -= c.saldo
        else
          existente.importe = total_sin_afectar
          total_sin_afectar = 0
        end
      end
    end

    def to_s
      nro_completo
    end

    def nro_completo
      "X #{nro.to_i}"
    end

    def secuenciador
      "tienda#{tienda_id}_recibos"
    end

    def nro_formateado
      format('%08d', nro.to_i)
    end

    private

    def asignar_tipo
      return unless new_record?

      self.tipo = Comprobantes::Tipo.find_by(codigo: 4)
    end
  end
end
