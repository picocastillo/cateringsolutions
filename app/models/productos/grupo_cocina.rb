module Productos
  class GrupoCocina < ApplicationRecord
    has_many :categorias, -> { order :nombre }, class_name: 'Productos::Categoria', foreign_key: 'grupo_cocina_id'

    belongs_to :tienda, class_name: 'Tiendas::Tienda'

    validates :nombre, uniqueness: { scope: :tienda_id }
    validates :nombre, presence: true

    before_create :asignar_codigo

    def to_s
      nombre
    end

    private

    def asignar_codigo
      return if codigo.present?

      self.codigo = Infraestructura::GeneradorSecuencial.proximo("tienda#{tienda_id}_grupos-cocina")
    end
  end
end
