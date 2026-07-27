module Ventas
  module Facturacion
    class ComprobanteContable < Comprobantes::Comprobante
      validates :cuenta, :tipo, :nro, presence: true

      def descripcion
        format("#{abreviatura} %08d", nro.to_i)
      end

      alias to_s descripcion

      def comprobante_contable?
        true
      end

      private

      def abreviatura
        tipo.desc == 'Débito Contable' ? 'DC' : 'CC'
      end
    end
  end
end
