module Pedidos
  class TurnoEntregaCategoria < ApplicationRecord
    self.table_name = 'turnos_entrega_categorias'

    # Associations
    belongs_to :turno_entrega, class_name: 'Pedidos::TurnoEntrega'
    belongs_to :categoria, class_name: 'Productos::Categoria'

    # Validations
    validates :categoria_id, uniqueness: { scope: :turno_entrega_id }
  end
end
