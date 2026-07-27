module Logistica
  module Flujos
    class Transferencia < MedioPago
      validates :importe, numericality: true

      def tipo_e_importe
        "Transferencia: #{importe}"
      end
    end
  end
end
