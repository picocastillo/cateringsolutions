module Metricas
  class Authorization < Ability::Subrules
    def add_rules
      can(:index, :metricas) if user.super_admin?
    end
  end
end
