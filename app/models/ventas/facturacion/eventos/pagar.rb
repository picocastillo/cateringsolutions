module Ventas
  module Facturacion
    module Eventos
      class Pagar < Evento
        enum :estado_generado, class_name: 'Comprobantes::Estado'

        def en_pasado
          'Pagado'
        end

        def disparable?
          cbte.confirmado? && (disparable_manual? || disparable_automatico?)
        end

        def estado_siguiente
          :confirmado
        end

        def disparable_manual?
          cbte.manual? && usuario.cumple_rol?(:facturacion)
        end

        def after_transition
          cbte.autor = usuario
          return unless cbte.valid?

          cbte.pagar_e_imputar
        end
      end
    end
  end
end
