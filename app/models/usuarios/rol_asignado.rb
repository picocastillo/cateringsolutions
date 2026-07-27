module Usuarios
  class RolAsignado < ApplicationRecord
    belongs_to :usuario
    belongs_to :rol
  end
end
