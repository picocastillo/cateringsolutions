module Ventas
  module Facturacion
    module Eventos
      class Evento < Infraestructura::Eventos::Evento
        alias_accessor :cbte, :origen
      end
    end
  end
end
