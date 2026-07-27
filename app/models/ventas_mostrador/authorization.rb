module VentasMostrador
  class Authorization < Ability::Subrules
    def add_rules
      return unless admin?

      can(:manage, DescuentoVentaMostrador) { |d| d.tienda == user.tienda_activa }
    end
  end
end
