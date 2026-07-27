module Usuarios
  class Grupo < ApplicationRecord
    acts_as_discontinued
    validates :nombre, presence: true, length: { maximum: 60 }, uniqueness: true

    before_destroy { throw :abort if owners.any? }

    def to_s
      nombre
    end

    def usuarios_alcanzados
      etiquetas.flat_map(&:usuarios_alcanzados)
    end

    def operadores?
      nombre == 'Operadores'
    end

    def especial?
      operadores?
    end
  end
end
