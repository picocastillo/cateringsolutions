module Infraestructura
  module Eventos
    class Evento < ApplicationRecord
      acts_as_list scope: :historial
      self.table_name = 'eventos'
      belongs_to :historial
      belongs_to :origen, polymorphic: true
      belongs_to :usuario, class_name: 'Usuarios::Usuario', optional: true
      serialize :mensajes, coder: YAML
      validate :evento_disparable, :validaciones_disparar, if: :disparando?
      after_validation :transcribir_errores, if: :disparando?

      scope :orden_descendiente, -> { order { position.desc } }
      scope :entre, ->(desde, hasta) { where { { fecha => desde.to_date.beginning_of_day..hasta.to_date.end_of_day } } }

      def self.accion
        name.demodulize.underscore.to_sym
      end

      delegate :accion, to: :class

      def disparar(origen)
        self.origen = origen
        self.historial = origen.historial
        before_validations
        @disparando = true
        return unless valid?

        @disparando = false
        before_transition
        registrar_evento
        after_transition
      end

      def clase
        human_name.titleize
      end
      alias to_s clase
      alias en_pasado to_s

      # Pisar para agregar validaciones que impidan el pasaje al siguiente estado y muestren un mensaje generico al usuario
      def disparable?
        true
      end

      def automatico?
        !usuario
      end

      def manual?
        !automatico?
      end

      private

      def registrar_evento
        self.fecha = Time.current
        origen.eventos << self
        estado_anterior = origen.estado
        estado_siguiente = do_transition
        self.estado_generado = estado_siguiente if estado_anterior != estado_siguiente || origen.eventos.size == 1
      end

      def error(msgs)
        Array(msgs).each { |msg| errors.add :base, msg }
      end

      def before_validations
        # Pisar para realizar tareas antes de validar el evento al dispararlo (no se van a ejecutar en el valid? normal para no ejecutarlas varias veces)
      end

      def validaciones_disparar
        # Pisar para agregar validaciones que se corran solo al disparar
      end

      def before_transition
        # Pisar para realizar tareas antes de pasar de estado, siempre que el evento sea disparable
      end

      def do_transition
        if (siguiente = estado_siguiente)
          origen.pasar_a_estado siguiente, usuario
          siguiente
        end
      end

      def after_transition
        # Pisar para realizar tareas despues de pasar de estado, siempre que el evento sea disparable
      end

      def estado_siguiente
        # Pisar para indicar el estado en el que quedara el origen
      end

      def disparando?
        !!@disparando
      end

      def evento_disparable
        error "Error: #{origen} no se puede #{accion.to_s.humanize.downcase}." unless disparable?
      end

      def transcribir_errores
        origen.ultimo_evento_fallido = self if errors.any?
      end
    end
  end
end
