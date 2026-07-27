module Logistica
  module Flujos
    module EventosFlujos
      class Finalizar < Evento
        def en_pasado
          'Finalizado'
        end

        def disparable?
          cbte.confirmado? && cbte.importe_a_cuenta.zero?
        end

        def estado_siguiente
          :finalizado
        end
      end
    end
  end
end
