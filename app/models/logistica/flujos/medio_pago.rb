module Logistica
  module Flujos
    class MedioPago < ApplicationRecord
      self.table_name = 'medios_pago'

      belongs_to :flujo_economico, class_name: 'Comprobantes::ComprobantePropio'
      belongs_to :cuenta, class_name: 'Clientes::Cuenta'
      money :importe
      validates :importe, numericality: { greater_than: 0, unless: :efectivo? }

      def efectivo?
        false
      end
    end
  end
end
