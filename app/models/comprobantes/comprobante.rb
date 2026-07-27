module Comprobantes
  class Comprobante < ApplicationRecord
    self.table_name = 'comprobantes'
    belongs_to :autor, class_name: 'Usuarios::Usuario', optional: true
    belongs_to :cuenta, class_name: 'Clientes::Cuenta'
    belongs_to :tipo
    attr_accessor :medio_de_pago

    belongs_to :pedido, class_name: 'Pedidos::Pedido', optional: true

    belongs_to :tienda, class_name: 'Tiendas::Tienda'

    enum :estado
    money :total

    validates :fecha_emision, date: true

    scope :pendientes, -> { where estado_id: 1 }
    scope :confirmados, -> { where estado_id: 3 }
    scope :emitidos_desde, ->(fecha) { where(comprobantes: { fecha_emision: fecha.to_date.beginning_of_day.. }) }
    scope :emitidos_hasta, ->(fecha) { where(comprobantes: { fecha_emision: ..fecha.to_date.end_of_day }) }
    scope :pedido_desde, ->(fecha) { joins(:pedido).merge(Pedidos::Pedido.fecha_desde(fecha)) }
    scope :pedido_hasta, ->(fecha) { joins(:pedido).merge(Pedidos::Pedido.fecha_hasta(fecha)) }

    has_many :documentos, -> { order :position }, as: :documentable, dependent: :destroy, class_name: 'Infraestructura::Documento'
    has_many :imagenes, lambda {
      order(:position).where('documento_content_type like "%image%"')
    }, as: :documentable, dependent: :destroy, class_name: 'Infraestructura::Documento'

    defaults fecha_emision: -> { Time.current }

    def comprobante_contable?
      false
    end

    def resumen
      'Concepto'
    end

    def letra
      'C'
    end

    def as_json(options = {})
      super(options.reverse_merge(only: :id, methods: [:descripcion]))
    end
  end
end
