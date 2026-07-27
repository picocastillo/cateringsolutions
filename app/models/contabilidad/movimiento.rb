module Contabilidad
  class Movimiento < ApplicationRecord
    self.table_name = 'movimientos_cbles'
    belongs_to :comprobante, class_name: 'Comprobantes::Comprobante'
    belongs_to :imputado, class_name: 'Comprobantes::Comprobante', optional: true
    belongs_to :afectacion, class_name: 'Comprobantes::Afectacion', optional: true
    belongs_to :cuenta, class_name: 'Clientes::Cuenta'

    belongs_to :tienda, class_name: 'Tiendas::Tienda'
    money :importe, :saldo

    before_validation :setear_tienda
    after_create :update_indice

    attr_accessor :condicion, :saldo_cuenta

    def debe
      importe_condicionado.positive? ? importe_condicionado : nil
    end

    def haber
      importe_condicionado.negative? ? importe_condicionado * - 1 : nil
    end

    def importe_condicionado
      if comprobante.estado == :anulado
        0.0
      else
        condicion.blank? ? importe : saldo
      end
    end

    def estado
      if saldo.zero?
        'Confirmado'
      elsif importe != saldo
        'Parcial'
      else
        'Pendiente'
      end
    end

    def vencimiento
      return unless comprobante.fecha_vencimiento

      restantes = saldo.zero? ? '' : " (#{dias_vencidos}d)"
      comprobante.fecha_vencimiento.to_s + restantes
    end

    def dias_vencidos
      (Time.zone.today - comprobante.fecha_vencimiento).to_i
    end

    private

    def update_indice
      update_column :indice, id
    end

    def setear_tienda
      self.tienda = derive_tienda
    end

    def derive_tienda
      return comprobante.tienda if comprobante.respond_to?(:tienda) && comprobante&.tienda
      return nil unless cuenta&.cliente

      cuenta.cliente.tiendas.first
    end
  end
end
