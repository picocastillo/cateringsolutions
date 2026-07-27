module Comprobantes
  class Tipo < ApplicationRecord
    self.table_name = 'tipos_comprobantes'

    def self.[](desc)
      find_by desc: desc
    end

    def codigo_to_s
      '%02d' % codigo
    end

    def abrev
      clase.scan(/[A-Z]/).join + letra
    end

    def inicial
      clase.scan(/[A-Z]/).last
    end

    def name
      clase.underscore
    end

    def to_s
      desc
    end

    def categoria
      desc.gsub(/\b[A-Z]\b/, '').strip
    end

    def self.categorias
      first(6).to_h { |t| [t.clase.underscore, t.categoria] }
    end

    def formato_corto
      return 'OP' if clase == 'Ventas::Facturacion::OrdenPago'

      prefix = {
        'Ventas::Facturacion::Factura' => 'RTO',
        'Ventas::Facturacion::NotaDebito' => 'ND',
        'Ventas::Facturacion::NotaCredito' => 'NC'
      }[clase]
      "#{prefix}#{letra}"
    end

    def signear(monto)
      monto * (debitan? ? 1 : -1) if monto
    end
  end
end
