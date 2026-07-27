module Infraestructura
  module Eventos
    class Historial < ApplicationRecord
      self.table_name = 'historiales'
      has_many :eventos, lambda {
        order :position
      }, class_name: 'Infraestructura::Eventos::Evento', dependent: :destroy, autosave: true

      def disparado?(evento)
        ultimo_evento(evento).present?
      end

      def ultimo_evento(evento)
        eventos.reverse.detect { |e| e.accion == evento }
      end
    end
  end
end
