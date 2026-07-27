module Entregas
  class Pago < Logistica::Flujos::FlujoEconomico
    def to_s
      "Pago #{nro}"
    end

    def debita?
      true
    end

    def importe_a_cuenta
      total + total_afectado
    end

    def secuenciador
      "tienda#{tienda_id}_pagos"
    end

    private

    def asignar_tipo
      return unless new_record?

      self.tipo = Comprobantes::Tipo.find_by(codigo: 6)
    end

    def afectados_debitan
      afectaciones.select(&:afectado).each do |a|
        c = a.afectado
        if c.debita?
          errors.add :base,
                     "El comprobante #{c} no se puede afectar. Por favor seleccione facturas o notas de débito."
        end
        errors.add :base, "El comprobante #{c} no corresponde a la cuenta #{c.cuenta}." if c.cuenta != cuenta
      end
    end
  end
end
