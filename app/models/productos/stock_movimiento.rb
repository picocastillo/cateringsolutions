module Productos
  class StockMovimiento < ApplicationRecord
    self.table_name = 'productos_stock_movimientos'

    # Associations
    belongs_to :stock, class_name: 'Productos::Stock'
    belongs_to :usuario, class_name: 'Usuarios::Usuario', optional: true

    # Validations
    validates :tipo, presence: true, inclusion: {
      in: ['entrada', 'salida', 'ajuste_entrada', 'ajuste_salida', 'venta', 'devolucion', 'transferencia']
    }
    validates :cantidad, presence: true, numericality: { greater_than: 0 }
    validates :cantidad_anterior, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :cantidad_nueva, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :fecha, presence: true

    # Scopes
    scope :entradas, -> { where(tipo: ['entrada', 'ajuste_entrada', 'devolucion']) }
    scope :salidas, -> { where(tipo: ['salida', 'ajuste_salida', 'venta', 'transferencia']) }
    scope :por_fecha, ->(desde, hasta) { where(fecha: desde..hasta) }
    scope :por_tipo, ->(tipo) { where(tipo: tipo) }
    scope :recientes, -> { order(fecha: :desc) }

    # Callbacks
    before_validation :set_default_fecha, on: :create

    def to_s
      "#{tipo.humanize} - #{cantidad} unidades (#{fecha.strftime('%d/%m/%Y %H:%M')})"
    end

    def entrada?
      ['entrada', 'ajuste_entrada', 'devolucion'].include?(tipo)
    end

    def salida?
      ['salida', 'ajuste_salida', 'venta', 'transferencia'].include?(tipo)
    end

    def diferencia
      entrada? ? cantidad : -cantidad
    end

    def producto
      stock&.producto
    end

    def tienda
      stock&.tienda
    end

    # Class methods for reporting
    def self.resumen_movimientos(stock_id, desde = nil, hasta = nil)
      movimientos = where(stock_id: stock_id)
      movimientos = movimientos.por_fecha(desde, hasta) if desde && hasta

      {
        total_entradas: movimientos.entradas.sum(:cantidad),
        total_salidas: movimientos.salidas.sum(:cantidad),
        cantidad_movimientos: movimientos.count,
        ultimo_movimiento: movimientos.recientes.first&.fecha
      }
    end

    def self.reporte_por_producto(producto_id, desde = nil, hasta = nil)
      joins(:stock)
        .where(productos_stocks: { producto_id: producto_id })
        .then { |q| desde && hasta ? q.por_fecha(desde, hasta) : q }
        .group(:tipo)
        .sum(:cantidad)
    end

    def self.movimientos_por_tienda(tienda_id, desde = nil, hasta = nil)
      joins(stock: :tienda)
        .where(tiendas: { id: tienda_id })
        .then { |q| desde && hasta ? q.por_fecha(desde, hasta) : q }
        .includes(stock: :producto)
        .recientes
    end

    private

    def set_default_fecha
      self.fecha ||= Time.current
    end
  end
end
