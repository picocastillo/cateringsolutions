module Infraestructura
  module Eventos
    module Workflow
      extend ActiveSupport::Concern

      included do
        belongs_to :historial, class_name: 'Infraestructura::Eventos::Historial', dependent: :destroy, autosave: true
        attr_accessor :ultimo_evento_fallido

        validate :ultimo_evento_valido
        delegate :disparado?, :eventos, :eventos=, to: :historial
        lazy historial: proc { Historial.new }

        class_attribute :eventos_posibles
        self.eventos_posibles = []

        cargar_eventos "app/models/#{File.dirname(name.underscore)}/eventos"
      end

      module ClassMethods
        def cargar_eventos(path_eventos)
          mixin = const_set :WorkflowMethods, Module.new
          Dir["#{path_eventos}/*.rb"].each do |file|
            filename = file[%r{app/models/(.*)\.rb}, 1]
            next if %(authorization evento workflow).include?(File.basename(filename))

            clase_evento = filename.camelize.constantize
            next unless clase_evento.respond_to?(:accion)

            self.eventos_posibles += [clase_evento]

            mixin.module_eval <<-END, __FILE__, __LINE__ + 1
              def #{clase_evento.accion} usuario = nil, args = {}
                raise "El primer argumento de los eventos debe ser un usuario" if usuario && !usuario.is_a?(Usuarios::Usuario)
                disparar #{clase_evento}.new args.merge(usuario: usuario)
              end

              def #{clase_evento.accion}! *args
                wrap_in_trx_and_save { #{clase_evento.accion} *args }
              end

              def puede_#{clase_evento.accion}? usuario, args = {}
                disparable? #{clase_evento}, usuario, args
              end
            END
          end
          logger.warn "No se encontraron eventos en '#{path_eventos}'" if eventos_posibles.empty?
          include mixin
        end
      end

      def en_estado? *estados
        estados.any? { |e| estado == e }
      end

      def disparable?(clase_evento, usuario, args = {})
        clase_evento.new(args.merge(usuario: usuario, origen: self)).disparable?
      end

      def pasar_a_estado(nuevo, _usuario = nil)
        self.estado = nuevo
      end

      def pasar_a_estado!(nuevo)
        pasar_a_estado nuevo
        save!
      end

      def ultimo_evento(clase = nil)
        clase ? historial.ultimo_evento(clase) : eventos.last
      end

      def disparar(evento)
        evento.disparar self
        self
      end

      def disparar!(evento)
        wrap_in_trx_and_save { disparar evento }
      end

      private

      def ultimo_evento_valido
        @ultimo_evento_fallido.errors.full_messages.each { |e| errors.add :base, e } if @ultimo_evento_fallido
      end

      def wrap_in_trx_and_save
        ret = nil
        transaction do
          estado_anterior = estado
          unless (ret = yield.save)
            self.estado = estado_anterior
            raise ActiveRecord::Rollback
          end
        end
        ret
      end
    end
  end
end
