module Ventas
  module Facturacion
    class Authorization < Ability::Subrules
      def add_rules
        if admin?
          can(:manage, Comprobante) { |c| c.tienda == user.tienda_activa }
          can(:xls_index, Comprobante)
        else
          if rol?(:gestiona_comprobantes)
            can :index, Comprobante
            can :json_index, Comprobante
            can(:change, Comprobante) { |c| c.tienda == user.tienda_activa }
            cannot(:xls_index, Comprobante)
          end
          can(:show, Comprobante) { |c| c.tienda == user.tienda_activa && c.cuenta&.cliente == user.cliente } if rol?(:administrador_empresa)
        end
      end
    end
  end
end
