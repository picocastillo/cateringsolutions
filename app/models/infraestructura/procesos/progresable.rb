module Infraestructura
  module Procesos
    module Progresable
      def self.included(base)
        base.instance_eval do
          has_one :progreso, class_name: 'Infraestructura::Procesos::Progreso', as: :progresable, autosave: true,
                             dependent: :destroy
          after_initialize { self.progreso ||= Progreso.new }
          before_save :progreso
        end
      end

      def generando_archivo?
        !progreso.termino? && progreso.pje == 100
      end
    end
  end
end
