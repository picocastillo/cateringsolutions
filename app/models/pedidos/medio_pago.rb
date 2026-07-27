module Pedidos
  class MedioPago < ApplicationRecord
    self.table_name = 'pedidos_medios_pago'

    TIPOS = {
      'efectivo' => 'Efectivo',
      'debito' => 'Débito',
      'credito' => 'Crédito',
      'qr' => 'QR',
      'transferencia' => 'Transferencia'
    }.freeze

    belongs_to :pedido, class_name: 'Pedidos::Pedido'

    validates :tipo, presence: true, inclusion: { in: TIPOS.keys }
    validates :importe, numericality: { greater_than: 0 }

    def tipo_label
      TIPOS[tipo]
    end
  end
end
