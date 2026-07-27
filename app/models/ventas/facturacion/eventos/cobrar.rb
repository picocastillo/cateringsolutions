module Ventas
  module Facturacion
    module Eventos
      class Cobrar < Evento
        enum :estado_generado, class_name: 'Comprobantes::Estado'

        def en_pasado
          'Cobrado'
        end

        def disparable?
          cbte.confirmado? && (disparable_automatico? || disparable_manual?)
        end

        def estado_siguiente
          :confirmado
        end

        def disparable_manual?
          cbte.manual? && usuario.cumple_rol?(:facturacion)
        end

        def disparable_automatico?
          !usuario
        end

        def after_transition
          cbte.autor = usuario
          return unless cbte.valid?

          cbte.cobrar_e_imputar usuario
        end
      end
    end
  end
end
