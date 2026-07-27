module Logistica
  module Flujos
    class FlujoEconomico < Comprobantes::ComprobantePropio
      cargar_eventos "#{__dir__}/eventos_flujos"

      MediosPago = [:efectivos, :retenciones, :mercado_pagos, :debitos, :creditos, :qrs, :transferencias].freeze
      [:efectivos, :retenciones, :debitos, :creditos, :qrs, :transferencias].each do |medio|
        has_many medio, extend: Comprobantes::Totalizable, foreign_key: :flujo_economico_id, after_add: lambda { |t, i|
          i.cuenta = t.cuenta
          i.flujo_economico = t
        }
        accepts_nested_attributes_for medio, allow_destroy: true, reject_if: ->(attrs) { attrs['importe'].to_f.zero? }
      end

      has_many :mercado_pagos, extend: Comprobantes::Totalizable, class_name: '::Logistica::Flujos::MercadoPago', after_add: lambda { |t, i|
        i.cuenta = t.cuenta
        i.flujo_economico = t
      }
      accepts_nested_attributes_for :mercado_pagos, allow_destroy: true, reject_if: lambda { |attrs|
        attrs['importe'].to_f.zero?
      }

      enum :estado, class_name: 'Logistica::Flujos::EstadoFlujo'

      before_validation :cachear_total

      validates :cuenta, presence: true
      validates :total, numericality: { greater_than: 0, message: 'recibido (%<value>s) debe ser positivo' },
                        if: :confirmado?
      # validates :total_afectado, numericality: {less_than_or_equal_to: :total}, if: :total_positivo
      validate :afectados_debitan, :afectaciones_con_saldo, :afectaciones_viejas_intocables

      delegate :confirmado?, to: :estado

      def to_s
        "Recibo #{nro}"
      end

      def fecha_emision
        super.try :to_date
      end

      def cachear_total
        self.total = medios_pago.map(&:importe).sum
      end

      def medios_pago
        MediosPago.flat_map { |m| send(m).preserved }
      end

      def debita?
        false
      end

      private

      def afectados_debitan
        afectaciones.select(&:afectado).each do |a|
          c = a.afectado
          if c.acredita?
            errors.add :base,
                       "El comprobante #{c} no se puede afectar. Por favor seleccione facturas o notas de débito."
          end
          errors.add :base, "El comprobante #{c} no corresponde a la cuenta #{c.cuenta}." if c.cuenta != cuenta
        end
      end

      def afectaciones_con_saldo
        afectaciones_no_contabilizadas.reject(&:marked_for_destruction?).group_by(&:afectado).each do |c, as|
          if c && (c.saldo < as.map(&:importe).sum)
            errors.add :base,
                       "El comprobante #{c} tiene saldo #{c.saldo}, no se puede afectar por #{as.map(&:importe).sum}."
          end
        end
      end

      def afectaciones_viejas_intocables
        afectaciones_contabilizadas.each do |a|
          errors.add :base, 'No puede cambiar afectaciones contabilizadas' if !a.new_record? && a.changed?
        end
      end

      def total_positivo
        total.positive?
      end
    end
  end
end
