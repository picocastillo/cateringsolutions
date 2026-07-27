module Logistica
  module Flujos
    class Efectivo < MedioPago
      validates :importe, numericality: true

      def efectivo?
        true
      end

      def tipo_e_importe
        "Efectivo: #{importe}"
      end
    end
  end
end
