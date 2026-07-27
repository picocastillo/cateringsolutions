module Infraestructura
  module Procesos
    class LanzarProcesoJob < ApplicationJob
      queue_as :slow

      discard_on ActiveJob::DeserializationError

      def perform(proceso)
        proceso.perform
      end

      after_perform do |_job|
        nil # Hook for subclasses
      end
    end
  end
end
