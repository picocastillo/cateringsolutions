module Usuarios
  class Preferencia < ApplicationRecord
    belongs_to :usuario, class_name: 'Usuarios::Usuario'

    def self.obtener(n, u)
      Preferencia.where(usuario: u, nombre: n).first_or_create
    end
  end
end
