module Locales
  class Authorization < Ability::Subrules
    def add_rules
      return unless admin?

      can(:manage, Local) { |l| user.tiendas.include?(l.tienda) || user.id == 1 }
    end
  end
end
