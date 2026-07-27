module Comprobantes
  class ComprobantePropio < Comprobante
    include Contabilidad::Imputable
    include Infraestructura::Eventos::Workflow

    has_many :afectaciones, lambda {
      order :created_at
    }, autosave: true, foreign_key: :comprobante_id, extend: Totalizable,
       dependent: :destroy, class_name: 'Comprobantes::Afectacion',
       before_add: lambda { |t, i|
         i.comprobante = t
       }
    has_many :afectados, through: :afectaciones
    has_many :afectaciones_inversas, foreign_key: :afectado_id, class_name: 'Comprobantes::Afectacion'
    has_many :afectadores, through: :afectaciones_inversas, source: :comprobante

    accepts_nested_attributes_for :afectaciones, allow_destroy: true, reject_if: lambda { |attrs|
      attrs['importe'].to_f.zero?
    }

    before_validation :asignar_tipo
    before_validation :setear_tienda
    before_destroy :revertir_comprobantes

    def importe_a_cuenta
      total - total_afectado
    end

    def revertir_comprobantes
      afectaciones.each(&:borrar_movimientos)
      afectadores.select { |x| x.afectaciones.one? }.each(&:destroy)
    end

    def total_afectado
      afectaciones.importe_total
    end

    def recalcular_saldos(importe_afectado)
      movimientos.each do |m|
        m.saldo = m.saldo + importe_afectado
        m.save
      end
    end

    def finalizado?
      en_estado? :finalizado
    end

    private

    def afectados_confirmados
      afectados.select(&:confirmado?)
    end

    def afectadores_confirmados
      afectadores.select { |x| x.confirmado? || x.finalizado? }
    end

    def setear_tienda
      return unless new_record? && tienda.nil?

      self.tienda = pedido&.tienda || cuenta&.cliente&.tiendas&.first # rubocop:disable Style/SafeNavigationChainLength
    end
  end
end
