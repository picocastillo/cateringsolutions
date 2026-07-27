module Usuarios
  class GruposQuery < ApplicationQuery
    attr_accessor :nombre, :descripcion, :status, :usuario

    def relation
      q = Grupo.order(:nombre).status(status)
      q = q.where('nombre like ?', "%#{nombre}%") if nombre.present?
      q = q.where('descripcion like ?', "%#{descripcion}%") if descripcion.present?
      q
    end
  end
end
