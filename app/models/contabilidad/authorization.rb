module Contabilidad
  class Authorization < Ability::Subrules
    def add_rules
      if admin?
        can(:manage, Movimiento) { |c| c.tienda == user.tienda_activa }
      else
        if rol?(:gestiona_movimientos)
          can :index, Movimiento
          can :json_index, Movimiento
          can(:change, Movimiento) { |c| c.tienda == user.tienda_activa }
          cannot(:xls_index, Movimiento)
        end
        if rol?(:administrador_empresa)
          can :index, Movimiento
          cannot(:xls_index, Movimiento)
        end
      end
    end
  end
end
