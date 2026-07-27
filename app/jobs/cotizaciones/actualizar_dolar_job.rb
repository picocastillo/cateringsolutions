module Cotizaciones
  class ActualizarDolarJob < ApplicationJob
    queue_as :fast

    def perform(fecha_str = nil)
      fecha = fecha_str ? Date.parse(fecha_str) : Date.current

      # Skip if rate already exists for this date
      return if Cotizaciones::Dolar.exists?(fecha: fecha)

      Cotizaciones::Dolar.actualizar!(fecha)
    end
  end
end
