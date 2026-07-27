module Pedidos
  class ClienteTurnoEntrega < ApplicationRecord
    self.table_name = 'clientes_turnos_entrega'

    # Associations
    belongs_to :cliente, class_name: 'Clientes::Cliente'
    belongs_to :turno_entrega, class_name: 'Pedidos::TurnoEntrega'

    # Validations
    validates :turno_entrega_id, uniqueness: { scope: :cliente_id }
  end
end
