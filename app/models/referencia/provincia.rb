module Referencia
  class Provincia < ApplicationRecord
    on_const_missing_detect_by :nombre

    def to_s
      nombre
    end
  end
end
