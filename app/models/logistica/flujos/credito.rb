module Logistica
  module Flujos
    class Credito < MedioPago
      validates :importe, numericality: true

      def tipo_e_importe
        "Crédito: #{importe}"
      end
    end
  end
end
