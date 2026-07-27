module MenusDiarios
  class Authorization < Ability::Subrules
    def add_rules
      if admin?
        can(:manage, MenuDiario) { |c| c.tienda == user.tienda_activa }
      elsif rol?(:gestiona_menus_diarios)
        can :index, MenuDiario
        can :json_index, MenuDiario
        can(:change, MenuDiario) { |c| c.tienda == user.tienda_activa }
        cannot(:xls_index, MenuDiario)
      end
    end
  end
end
