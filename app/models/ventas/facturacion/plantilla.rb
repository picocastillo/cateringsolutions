module Ventas
  module Facturacion
    class Plantilla < ApplicationRecord
      self.table_name = 'plantillas'
      validates :nombre, :clase_cbte, presence: true

      def to_s
        nombre
      end

      def self.para(comprobante)
        where(clase_cbte: comprobante.class.name.demodulize).to_a
      end
    end
  end
end
