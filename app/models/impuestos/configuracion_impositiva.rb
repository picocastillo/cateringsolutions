module Impuestos
  class ConfiguracionImpositiva < ApplicationRecord
    self.table_name = 'configuraciones_impositivas'

    belongs_to :cliente, class_name: 'Clientes::Cliente'
    enum :impuesto
    enum :condicion, class_name: 'Impuestos::CondicionImpositiva'

    validates :impuesto, presence: { class_name: 'Impuestos::Impuesto' }
    validates :condicion, presence: { unless: proc { |this| this.impuesto.suss? } }

    delegate :inscripto_iva?, :monotributista?, :no_gravado_iva?, :no_inscripto_gcias?, to: :condicion

    lazy condicion: ->(this) { CondicionImpositiva.all_for(this.impuesto).first }

    def exencion_percepcion_para(_jurisdiccion = nil)
      exencion_percepcion
    end
  end
end
