module Ventas
  module Facturacion
    class PagoElectronico < ApplicationRecord
      self.table_name = 'pagos_electronicos'
      acts_as_list scope: [:pedido]
      belongs_to :pedido, class_name: 'Pedidos::Pedido'
    end
  end
end
