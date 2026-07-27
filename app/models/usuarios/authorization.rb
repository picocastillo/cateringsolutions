module Usuarios
  class Authorization < Ability::Subrules
    def add_rules
      if admin?
        # Step 5 of shared-clientes migration: cliente users are reachable when
        # their cliente is HABTM-linked to admin's tienda_activa (not just when
        # tienda_cliente matches). Admin/operador users still keyed off
        # usuarios_tiendas.
        can(:manage, Usuario) do |otro_user|
          (otro_user.tiendas.include?(user.tienda_activa) && !otro_user.cuenta_id) ||
            otro_user.cliente&.disponible_en?(user.tienda_activa)
        end
        cannot(:destroy, Usuario) { |u| u.id == 1 }
        can :json_index, Usuario
        can :index, Usuario
        can(:xls_index, Usuario)
      elsif rol? :gestiona_usuarios
        can(:show, Usuario) { |otro_user| otro_user.tienda == user.tienda_activa }
        can :index, Usuario
        can(:change, Usuario) do |otro_user|
          otro_user.tiendas.include?(user.tienda_activa) && !otro_user.admin? &&
            (!otro_user.cuenta_id || otro_user.cliente&.disponible_en?(user.tienda_activa))
        end
        can(:xls_index, Usuario)
      end
      can :index_js, Usuario
      can(:show, Usuario) do |cu|
        cu == user || (user.cliente && user.cumple_rol?(:administrador_empresa) && user.cliente == cu.cliente)
      end
      can(:editar_cuenta, Usuario) { |cu| cu == user }
    end
  end
end
