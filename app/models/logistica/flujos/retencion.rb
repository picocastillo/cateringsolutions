module Logistica
  module Flujos
    class Retencion < MedioPago
      validates :fecha_retencion, date: true

      def tipo_e_importe
        "Retención: #{importe}"
      end
    end
  end
end
