module Logistica
  module Flujos
    module EventosFlujos
      class Evento < Ventas::Facturacion::Eventos::Evento
        enum :estado_generado, class_name: 'Logistica::Flujos::EstadoFlujo'
      end
    end
  end
end
