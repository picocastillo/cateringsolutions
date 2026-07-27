module Ventas
  module Facturacion
    class NotaDebito < Comprobante
      def nota_debito?
        true
      end

      def nota?
        true
      end

      def rol_asociado
        :generar_notas_debito
      end

      private

      def asignar_tipo
        return unless new_record?

        self.tipo = Comprobantes::Tipo.find_by(codigo: 2)
      end
    end
  end
end
