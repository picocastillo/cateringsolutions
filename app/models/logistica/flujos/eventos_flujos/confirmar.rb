module Logistica
  module Flujos
    module EventosFlujos
      class Confirmar < Evento
        def en_pasado
          'Confirmado'
        end

        def disparable?
          cbte.estado.pendiente? && cbte.total != 0
        end

        def estado_siguiente
          :confirmado
        end

        def after_transition
          cbte.fecha_emision = Time.current
          cbte.autor = usuario
          return unless cbte.valid?

          asignar_nro
          cbte.contabilizar
          cbte.finalizar(usuario) if cbte.importe_a_cuenta.zero?
        end

        def asignar_nro
          cbte.nro = Infraestructura::GeneradorSecuencial.proximo("tienda#{cbte.tienda_id}_#{cbte.secuenciador}")
        end
      end
    end
  end
end
