module Pedidos
  class Authorization < Ability::Subrules
    def add_rules
      cannot(:xls_index, Pedidos::Pedido)
      if admin?
        can([:index, :edit, :new, :update, :create], Pedidos::Horario) { |x| user.tienda_activa.horarios_de_entrega? && (!x.tienda || x.tienda == user.tienda_activa) }
        can([:destroy], Pedidos::Horario)  do |x|
          (!x.tienda || x.tienda == user.tienda_activa) && user.tienda_activa.horarios_de_entrega? && !Pedidos::Pedido.exists?(
            tienda_id: user.tienda_activa.id, horario_id: x.id
          )
        end
        can(:read, Pedidos::PedidoMultiple)
        can(:index, Pedidos::Pedido) if user.tienda_activa.carrito_de_compras?
        can(:create, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) }
        can(:create_fast, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) }
        can :show, Pedidos::Pedido
        can(:index, :despachos) if !user.cliente? && user.tienda_activa.despachos?
        can(:xls_index, :despachos) unless user.cliente?
        can :carga_rapida, Pedidos::Pedido
        can :json_index, Pedidos::Pedido
        can :import, Pedidos::Pedido
        can(:create, Pedidos::PedidoCocina)
        can(:index, Pedidos::PedidoCocina)
        can(:show, Pedidos::PedidoCocina) { |x| x.tienda == user.tienda_activa }
        can(:destroy, Pedidos::PedidoCocina) { |x| x.tienda == user.tienda_activa && x.created_at && x.created_at > 12.hours.ago }
        can(:xls_index, Pedidos::Pedido)
        can(:destroy, Pedidos::Pedido) { |x| (x.verificar_tienda(user.tienda_activa) && can?(:edit, x)) || (x.estado_id == 2 && x.fecha_permitida? && !x.venta_mostrador) || (x.venta_mostrador && x.fecha > 7.days.ago && (x.fecha == Time.zone.today || x.estado_id < 4) && !x.cobrado?) }
        can(:limpiar, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) }
        can(:cancelar, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && x.estado_id == 3 }
        can(:agregar, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && x.estado_id == 1 }
        can(:edit, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && x.estado_id == 1 }
        can(:re_edit, Pedidos::Pedido) { |x| (x.verificar_tienda(user.tienda_activa) && can?(:edit, x)) || (x.estado_id == 2 && x.fecha_permitida? && !x.venta_mostrador) || (x.venta_mostrador && x.fecha > 7.days.ago && x.estado_id < 4) }
        can(:edit_rapido, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && x.estado_id < 4 }
        can(:aceptar, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && x.estado_id == 1 && x.productos_solicitados.present? && x.fecha_permitida? && x.cuenta&.cuenta_corriente_habilitada? }
        can(:pagar_mercadopago, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && x.estado_id == 1 && x.productos_solicitados.present? && x.fecha_permitida? && x.cuenta.present? && !x.cuenta.cuenta_corriente_habilitada? }
        can(:confirmar, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && x.estado_id == 2 && x.productos_solicitados.present? && x.fecha_permitida? }
      elsif user.cliente?
        can(:read, Pedidos::PedidoMultiple) { |g| g.pedidos.any? { |p| p.usuario == user || p.autor == user } || g.cuenta == user.cuenta || (user.cumple_rol?(:administrador_empresa) && user.cliente.cuentas.include?(g.cuenta)) }
        can(:index, Pedidos::Pedido) if user.tienda_activa.carrito_de_compras?
        can(:create, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) }
        can(:show, Pedidos::Pedido) { |x| (x.verificar_tienda(user.tienda_activa) && user == x.autor) || x.usuario == user || (rol?(:administrador_empresa) && user.cliente == x.cuenta.cliente) }
        can(:destroy, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && can?(:re_edit, x) }
        can(:re_edit, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && user == x.autor && (x.estado_id == 1 || (x.estado_id == 2 && x.fecha_permitida? && !x.venta_mostrador && !x.cobrado?)) }
        can(:edit, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && (user == x.autor || user == x.usuario || (user.cumple_rol?(:administrador_empresa) && user.cliente.cuentas.include?(x.cuenta))) && (x.estado_id == 1 || (x.estado_id == 2 && x.fecha_permitida?)) }
        can(:aceptar, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && can?(:edit, x) && x.productos_solicitados.present? && x.cuenta&.cuenta_corriente_habilitada? }
        can(:pagar_mercadopago, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && can?(:edit, x) && x.productos_solicitados.present? && x.cuenta.present? && !x.cuenta.cuenta_corriente_habilitada? }
        can(:confirmar, Pedidos::Pedido) { |x| x.verificar_tienda(user.tienda_activa) && user == x.autor && x.usuario == user && x.estado_id == 2 && x.productos_solicitados.present? && x.fecha_permitida? }
        can(:xls_index, Pedidos::Pedido)
      end
    end
  end
end
