module Cobros
  class Authorization < Ability::Subrules
    def add_rules
      if admin?
        can(:change, Recibo) { |c| c.tienda == user.tienda_activa && c.estado == Logistica::Flujos::EstadoFlujo[:pendiente] }
        can(:confirmar, Recibo) { |c| c.tienda == user.tienda_activa && c.estado == Logistica::Flujos::EstadoFlujo[:pendiente] }
      elsif rol?(:gestiona_recibos)
        can :index, Recibo
        can :json_index, Recibo
        can(:confirmar, Recibo) { |c| c.tienda == user.tienda_activa && c.estado == Logistica::Flujos::EstadoFlujo[:pendiente] }
        can(:change, Recibo) { |c| c.tienda == user.tienda_activa && c.estado == Logistica::Flujos::EstadoFlujo[:pendiente] }
        cannot(:xls_index, Recibo)
      end
    end
  end
end
