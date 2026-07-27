module Ventas
  module Facturacion
    module Eventos
      class Confirmar < Evento
        enum :estado_generado, class_name: 'Comprobantes::Estado'

        def en_pasado
          'Confirmado'
        end

        def disparable?
          cbte.pendiente? && disparable_automatico?
        end

        def estado_siguiente
          :confirmado
        end

        def disparable_manual?
          cbte.manual? && usuario.cumple_rol?(:gestiona_comprobantes)
        end

        def disparable_automatico?
          !cbte.nota_credito? || cbte.cancela_a
        end

        def after_transition
          cbte.autor = cbte.pedido.usuario if cbte.pedido&.usuario
          asignar_nro
          return unless cbte.valid?

          asignar_vencimiento
          cbte.generar_afectaciones
          cbte.contabilizar
        end

        def asignar_nro
          return if cbte.nro

          cbte.nro = Infraestructura::GeneradorSecuencial.proximo("tienda#{cbte.tienda_id}_#{cbte.class.name}")
        end

        def asignar_vencimiento
          return if cbte.fecha_vencimiento

          cbte.fecha_vencimiento = cbte.pedido ? cbte.pedido.cuenta.cliente.fecha_vencimiento : (cbte.fecha_emision + 7.days)
        end
      end
    end
  end
end
