module Logistica
  module Flujos
    class Qr < MedioPago
      validates :importe, numericality: true

      def tipo_e_importe
        "QR: #{importe}"
      end
    end
  end
end
