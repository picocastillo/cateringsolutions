module Cobros
  module CobrosHelper
    def acciones_recibo(r)
      as = []
      if r.disparable?(
        Logistica::Flujos::EventosFlujos::Anular, current_user
      ) && can?(:manage, r)
        as << link_to('Anular', anular_admin_recibo_path(r), method: :put,
                                                             data: { confirm: "Está seguro que desea anular el #{r}?" })
      end
      as << link_to('Editar', edit_admin_recibo_path(r)) if !r.estado.finalizado? && can?(:manage, r)
      as << link_to('Continuar Afectación', edit_admin_recibo_path(r)) if r.disparable?(
        Logistica::Flujos::EventosFlujos::ContinuarAfectacion, current_user
      )
      as
      # as << link_to('Eliminar', admin_recibo_path(r), data: {:confirm => 'Estas seguro?'}, :method => :delete)
    end

    def acciones_pago(r)
      as = []
      if r.disparable?(
        Logistica::Flujos::EventosFlujos::Anular, current_user
      ) && can?(:manage, r)
        as << link_to('Anular', anular_admin_pago_path(r), method: :put,
                                                           data: { confirm: "Está seguro que desea anular el #{r}?" })
      end
      as << link_to('Editar', edit_admin_pago_path(r)) if !r.estado.finalizado? && can?(:manage, r)
      as << link_to('Continuar Afectación', edit_admin_pago_path(r)) if r.disparable?(
        Logistica::Flujos::EventosFlujos::ContinuarAfectacion, current_user
      ) && can?(:manage, r)
      as
      # as << link_to('Eliminar', admin_pago_path(r), data: {:confirm => 'Estas seguro?'}, :method => :delete)
    end

    def preparar_afectaciones_pago(pago)
      pago_valido = pago.valid?
      pago.afectaciones.each { |a| a.seleccionado = true }
      Ventas::Facturacion::Comprobante.pendientes_para_pagar(pago.cuenta).each do |c|
        existente = pago.afectaciones.detect { |a| a.afectado == c }
        pago.afectaciones.build afectado: c, importe: c.saldo if !existente && pago_valido
      end
      pago.afectaciones.to_a.sort_by! do |a|
        [a.afectado.fecha_vencimiento, a.afectado.descripcion, a.created_at || Date.new(2050)]
      end
      pago
    end
  end
end
