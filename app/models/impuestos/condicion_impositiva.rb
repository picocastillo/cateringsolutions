module Impuestos
  class CondicionImpositiva < ArEnums::Base
    enumeration do
      inscripto_gcias id: 1, desc: 'Inscripto', aplicable_a: :gcias
      no_inscripto_gcias id: 2, desc: 'No Inscripto', aplicable_a: :gcias

      no_inscripto_iibb id: 8, desc: 'No Inscripto', aplicable_a: :iibb
      inscripto_directo id: 3, desc: 'Directo', aplicable_a: :iibb
      inscripto_convenio id: 4, desc: 'Convenio Multilateral', aplicable_a: :iibb

      inscripto_iva id: 5, desc: 'Resp. Inscripto', aplicable_a: :iva
      exento_iva id: 6, desc: 'Exento', aplicable_a: :iva
      monotributista id: 7, desc: 'Monotributista', aplicable_a: :iva
      no_gravado_iva id: 9, desc: 'No Gravado', aplicable_a: :iva
      consumidor_final id: 10, desc: 'Consumidor Final', aplicable_a: :iva
    end

    def self.all_for(impuesto)
      all.select { |ci| impuesto == ci.aplicable_a }.sort_by { |x| -x.id }
    end

    def self.find_by_id(id)
      all.detect { |ci| ci.id == id }
    end

    def self.find_by_aplicable_a_and_codigo_afip(aplicable_a, ca)
      all.detect { |ci| ci.aplicable_a.to_s == aplicable_a and ci.codigo_afip == ca }
    end
  end
end
