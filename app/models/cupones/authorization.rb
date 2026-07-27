module Cupones
  class Authorization < Ability::Subrules
    def add_rules
      return unless admin?

      can(:manage, Cupon) { |c| c.tienda == user.tienda_activa }
    end
  end
end
