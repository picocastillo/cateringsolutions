module Logistica
  module Flujos
    class EstadoFlujo < ArEnums::Base
      enumeration do
        pendiente desc: 'Pendiente', tip: 'Listo para confirmar e imputar pagos.'
        anulado desc: 'Anulado', tip: 'El recibo ha sido anulado.'
        confirmado desc: 'Confirmado', tip: 'El recibo ha sido confirmado.'
        finalizado desc: 'Finalizado', tip: 'El recibo ha sido finalizado. No se pueden realizar más afectaciones.'
      end

      def to_s
        desc
      end

      def self.find_by_desc(desc)
        all.detect { |ci| ci.desc == desc }
      end

      def self.find_by_name(name)
        all.detect { |ci| ci.name == name }
      end
    end
  end
end
