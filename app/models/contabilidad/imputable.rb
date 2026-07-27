module Contabilidad
  module Imputable
    extend ActiveSupport::Concern

    included do
      has_many :movimientos, class_name: 'Contabilidad::Movimiento', foreign_key: :comprobante_id, autosave: true,
                             dependent: :destroy
    end

    def contabilizar
      if debita? && !is_a?(Entregas::Pago)
        movimientos.build importe: total, saldo: total, cuenta: cuenta if movimientos.empty?
      else
        afectaciones_no_contabilizadas.each { |a| a.generar_movimientos self }
        generar_movimiento_a_cuenta
      end
      self
    end

    def afectaciones_no_contabilizadas
      afectaciones - movimientos.map(&:afectacion).compact
    end

    private

    def generar_movimiento_a_cuenta
      if (movimientos.none? { |m| m.imputado.nil? } || !movimientos.destroy_if do |m|
        m.imputado.nil? && m.importe != -importe_a_cuenta
      end.empty?) && importe_a_cuenta.positive?
        movimientos.build importe: -importe_a_cuenta, saldo: -importe_a_cuenta, cuenta: cuenta
      end
    end

    def afectaciones_contabilizadas
      afectaciones - afectaciones_no_contabilizadas
    end
  end
end
