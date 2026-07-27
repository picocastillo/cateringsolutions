module Referencia
  class Genero < ArEnums::Base
    enumeration do
      hombre desc: 'Hombre'
      mujer desc: 'Mujer'
    end

    def to_s
      desc
    end
  end
end
