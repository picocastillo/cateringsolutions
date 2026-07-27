module Comprobantes
  class Afectacion < ApplicationRecord
    self.table_name = 'afectaciones'

    belongs_to :comprobante, class_name: 'Comprobantes::Comprobante'
    belongs_to :afectado, class_name: 'Comprobantes::Comprobante'
    money :importe

    validate :validar_importe

    before_destroy :borrar_movimientos

    def generar_movimientos(cbte)
      cbte.movimientos.build importe: -importe, saldo: 0, imputado: afectado, cuenta: cbte.cuenta, afectacion: self
      m = afectado.contabilizar.movimientos[0]
      m.saldo -= importe
      m.save!
    end

    private

    def validar_importe
      errors.add :importe, 'debe ser mayor o igual a 0' if afectado.debita? && importe.negative?
      errors.add :importe, 'debe ser menor o igual a 0' if !afectado.debita? && importe.positive?
    end

    def borrar_movimientos
      if comprobante
        comprobante.movimientos.where(afectacion_id: id).destroy_all
        comprobante.recalcular_saldos importe
      end
      return unless afectado

      afectado.movimientos.where(afectacion_id: id).destroy_all
      afectado.recalcular_saldos(afectado.debita? ? importe : importe * -1.0)
    end
  end
end
