module Productos
  class Favorito < ApplicationRecord
    belongs_to :usuario, class_name: 'Usuarios::Usuario'
    belongs_to :producto, class_name: 'Productos::Producto'
  end
end
