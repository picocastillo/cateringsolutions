module Tiendas
  class Authorization < Ability::Subrules
    def add_rules
      if user.super_admin?
        can(:manage, Tienda)
        can(:cambiar_tienda, Tienda)
      end
      # Step 6 of shared-clientes migration: cliente users can call
      # /tiendas/cambiar_tienda_activa to switch among their tiendas_disponibles.
      # The controller does its own puede_loguearse_en? check, so this rule
      # only needs to let the request through CanCan.
      can(:cambiar_tienda_activa, Tienda) if user.cliente?

      return unless user.admin?

      can(:cambiar_tienda, Tienda) { |x| user.tiendas.include?(x) }
    end
  end
end
