module Impuestos
  class TasaIva < ArEnums::Base
    enumeration do
      no_gravado alicuota: 0.0, desc: 'No Gravado', codigo: 3
      iva_21 alicuota: 21.0, desc: 'Gravado 21.0%', codigo: 5
      iva_10_5 alicuota: 10.5, desc: 'Gravado 10.5%', codigo: 4
    end

    def alicuota!
      alicuota / 100.0
    end

    def to_s
      "#{alicuota.pretty}%"
    end

    def gravado?
      !no_gravado?
    end
  end
end
