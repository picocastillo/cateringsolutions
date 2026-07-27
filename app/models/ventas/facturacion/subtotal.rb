module Ventas
  module Facturacion
    class Subtotal < ApplicationRecord
      self.table_name = 'subtotales'

      belongs_to :comprobante
      enum :tasa_iva, class_name: 'Impuestos::TasaIva'

      money :base_imponible, :iva

      validates :base_imponible, numericality: { greater_than: 0 }

      delegate :gravado?, :no_gravado?, to: :tasa_iva

      def total_con_iva
        base_imponible + iva
      end

      def to_wsfe
        { id: tasa_iva.codigo, base_imp: base_imponible.to_f, importe: iva.to_f }
      end
    end
  end
end
