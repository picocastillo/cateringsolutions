module Impuestos
  class Impuesto < ArEnums::Base
    enumeration do
      iva desc: 'IVA'
      iibb desc: 'Ingresos Brutos', abrev: 'IIBB'
      gcias desc: 'Ganancias'
      suss desc: 'SUSS'
    end

    def to_s
      abrev or desc
    end
  end
end
