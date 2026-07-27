module Infraestructura
  module Procesos
    class Progreso < ApplicationRecord
      belongs_to :progresable, polymorphic: true
      serialize :errores, coder: YAML

      def track(total = 100)
        start total
        result = yield
        finish
        result
      end

      def start(total)
        write actual: 0, total: total, fecha_inicio: Time.current, fecha_fin: nil, errores: []
      end

      def finish
        write actual: total, fecha_fin: Time.current
        # Wait slightly longer than the Redis throttle (1s) to ensure the client
        # has received earlier progress broadcasts before we send the final one.
        # Without this, fast processes finish before the throttle window expires
        # and the page only refreshes on the fallback polling cycle.
        sleep 1.1
        broadcast_update(force: true)
      end

      def finish_with_error(error)
        self.errores ||= []
        add_error error
        self.fecha_inicio ||= Time.current
        finish
      end

      def cancelar
        write fecha_fin: Time.current, cancelado: true
        broadcast_update(force: true)
      end

      def pje
        return termino? ? 100 : 0 if total.zero?

        result = (actual * 100.0 / total).round
        result = 100 if result > 100
        result
      end

      def avanzar
        old_pje = pje
        self.actual = [actual + 1, total].min
        write actual: actual if old_pje != pje
      end

      def empezo?
        fecha_inicio and actual.positive?
      end

      def termino?
        fecha_inicio && fecha_fin
      end

      def ejecutando?
        empezo? and !termino? and !error?
      end

      def error?
        errores&.any? || false
      end

      def add_error(error)
        errores << error[0, 60_000]
      end

      def error!(error)
        add_error error
        save!
      end

      def eta
        return nil unless empezo?

        eta_in_secs = (Time.current - fecha_inicio) * ((total.to_f / actual) - 1)
        Time.current + eta_in_secs
      end

      def estado
        if cancelado?
          'Cancelado'
        elsif error?
          'Error'
        elsif termino?
          'Finalizado'
        elsif !empezo?
          'Pendiente'
        else
          'Ejecutando'
        end
      end

      def pendiente?
        estado == 'Pendiente'
      end

      # Es necesario recargar el objeto así sino no se actualiza el porcentaje
      def fue_cancelado?
        Progreso.find(id).cancelado?
      end

      def broadcast_update(force: false)
        return unless progresable.respond_to?(:autor_id) && progresable.autor_id

        unless force
          throttle_key = "procesos_broadcast_#{progresable.autor_id}"
          return if RedisServiceClient.throttled?(throttle_key)

          RedisServiceClient.setex(throttle_key, 1, Time.current.to_i)
        end
        channel = "procesos_#{progresable.autor_id}"
        Rails.logger.info "Procesos broadcast to #{channel}"
        ActionCable.server.broadcast(channel, broadcast_payload)
      rescue StandardError => e
        Rails.logger.warn "Procesos broadcast error: #{e.message}"
      end

      def broadcast_payload
        payload = { type: 'procesos_update', pje: pje, estado: estado }
        payload[:errores] = errores.first(5) if error?
        payload[:proceso_tipo] = progresable.class.name if progresable
        payload[:params] = progresable.params if progresable.respond_to?(:params) && progresable.params.present?
        payload.merge!(progresable.extra_broadcast_data) if progresable.respond_to?(:extra_broadcast_data)
        payload
      end

      private

      def write(attrs)
        self.attributes = attrs
        save unless new_record?
        broadcast_update unless new_record?
        self
      end
    end
  end
end
