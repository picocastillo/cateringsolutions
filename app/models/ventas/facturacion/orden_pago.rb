module Ventas
  module Facturacion
    class OrdenPago < Comprobante
      def pagar_e_imputar
        pago = Entregas::Pago.create cuenta: cliente.cuenta_principal,
                                     efectivos: [Logistica::Flujos::Efectivo.new(importe: -saldo)]
        pago.afectaciones.build afectado: self, importe: saldo
        pago.save!
        pago.confirmar!
      end

      def orden_pago?
        true
      end

      def debita?
        false
      end

      def determinar_letra
        'OP'
      end

      private

      def asignar_tipo
        return unless new_record?

        self.tipo = Comprobantes::Tipo.find_by(codigo: 5)
      end
    end
  end
end
