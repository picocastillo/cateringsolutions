module Clientes
  class Authorization < Ability::Subrules
    def add_rules
      if admin?
        # Step 5 of shared-clientes migration: use HABTM cliente↔tiendas link
        # so admins can manage clientes shared into their active tienda.
        can(:manage, Cliente) { |c| c.disponible_en?(user.tienda_activa) }
      elsif rol?(:gestiona_clientes)
        can :index, Cliente
        can :json_index, Cliente
        can(:change, Cliente) { |c| c.disponible_en?(user.tienda_activa) }
        cannot(:xls_index, Cliente)
      end
      can :index_js, Cuenta
    end
  end
end
