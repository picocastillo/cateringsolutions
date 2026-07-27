module Logistica
  module Flujos
    module EventosFlujos
      class Anular < Evento
        def en_pasado
          'Anulado'
        end

        def disparable?
          !cbte.estado.anulado?
        end

        def estado_siguiente
          :anulado
        end

        def after_transition
          cbte.afectaciones.each do |af|
            af.afectado.movimientos.each do |x|
              x.saldo = x.saldo + af.importe
              x.save!
            end
          end
          cbte.movimientos.destroy_all
        end
      end
    end
  end
end
