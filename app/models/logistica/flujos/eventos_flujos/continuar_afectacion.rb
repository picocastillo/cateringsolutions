module Logistica
  module Flujos
    module EventosFlujos
      class ContinuarAfectacion < Evento
        def en_pasado
          'Nueva Afectación'
        end

        def disparable?
          cbte.estado.confirmado? && cbte.importe_a_cuenta != 0
        end

        def validaciones_disparar
          return if cbte.afectaciones_no_contabilizadas.map(&:importe).sum.positive?

          error 'No hay nuevas afectaciones a contabilizar.'
        end

        def after_transition
          return unless cbte.valid?

          cbte.contabilizar
          cbte.finalizar(usuario) if cbte.importe_a_cuenta.zero?
        end
      end
    end
  end
end
