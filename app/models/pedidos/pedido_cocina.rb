module Pedidos
  class PedidoCocina < ApplicationRecord
    include Pedidos::Broadcastable

    self.table_name = 'pedidos_cocina'

    # Validations
    validates :codigo, presence: true
    validates :fecha, presence: true
    validates :pedidos, presence: true

    # Associations (add these as needed based on your existing models)
    belongs_to :autor, class_name: 'Usuarios::Usuario'
    has_many :pedidos, class_name: 'Pedidos::Pedido', dependent: :nullify
    belongs_to :tienda, class_name: 'Tiendas::Tienda'
    before_validation :set_codigo
    # Action Cable callbacks for real-time updates
    after_create :broadcast_daily_orders_update
    after_update :broadcast_daily_orders_update
    after_destroy :broadcast_daily_orders_update

    # Scopes
    scope :by_tienda, ->(tienda_id) { where(tienda_id: tienda_id) }

    # Instance methods
    def to_s
      "Pedido Cocina ##{codigo}"
    end

    private

    def set_codigo
      self.fecha = Time.zone.now if fecha.blank?
      self.codigo = Infraestructura::GeneradorSecuencial.proximo("tienda#{tienda_id}_cocina") if codigo.blank?
    end
  end
end
