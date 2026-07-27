module Logistica
  module Flujos
    class MercadoPago < MedioPago
      validates :importe, numericality: true
      belongs_to :pago_electronico, class_name: 'Ventas::Facturacion::PagoElectronico'

      def efectivo?
        false
      end

      def tipo_e_importe
        "Mercado Pago: #{importe} (ID Transacción #{pago_electronico.pago_id})"
      end
    end
  end
end
