module Logistica
  module Flujos
    class Debito < MedioPago
      validates :importe, numericality: true

      def tipo_e_importe
        "Débito: #{importe}"
      end
    end
  end
end
