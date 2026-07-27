module Infraestructura
  class Authorization < Ability::Subrules
    def add_rules
      if user.admin?
        can(:manage, Documento)
        can(:index, :inicio)
        can(:xls_index, :inicio)
      end
      if user.operador?
        can(:change, Documento)
        can(:index, :inicio)
        can(:xls_index, :inicio)
      end
      can(:manage, Documento) { |x| x.documentable == user } if user.cliente?
      can(:index, :procesos)
      can(:destroy, Procesos::Proceso) { |p| p.tienda_id == user.tienda_activa&.id } if user.admin? || user.operador?
    end
  end
end
