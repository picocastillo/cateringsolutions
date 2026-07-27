module Pedidos
  class Horario < ApplicationRecord
    acts_as_discontinued
    acts_as_list scope: :tienda

    has_many :pedidos, class_name: 'Pedidos::Pedido'
    belongs_to :tienda, class_name: 'Tiendas::Tienda'

    after_save :rectificar_predeterminado

    delegate :to_s, to: :nombre

    def por_defecto=(b)
      self.predeterminado = ActiveModel::Type::Boolean.new.cast(b)
    end

    def por_defecto
      predeterminado
    end

    private

    def rectificar_predeterminado
      Horario.where(tienda_id: tienda_id).where.not(id: id).update_all(predeterminado: false) if predeterminado
    end
  end
end
