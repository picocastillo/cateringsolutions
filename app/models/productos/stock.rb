module Productos
  class Stock < ApplicationRecord
    self.table_name = 'productos_stocks'

    # Associations
    belongs_to :producto, class_name: 'Productos::Producto'
    belongs_to :tienda, class_name: 'Tiendas::Tienda'
    belongs_to :local, class_name: 'Locales::Local', optional: true
    has_many :stock_movimientos, dependent: :destroy, class_name: 'Productos::StockMovimiento'

    # Validations
    validates :cantidad_actual, numericality: { greater_than_or_equal_to: 0 }
    validates :cantidad_minima, numericality: { greater_than_or_equal_to: 0 }
    validates :cantidad_maxima, numericality: { greater_than: 0 }, allow_nil: true
    validates :producto_id, uniqueness: { scope: [:tienda_id, :local_id], message: 'ya existe' }

    validate :cantidad_maxima_mayor_que_minima
    validate :producto_pertenece_a_tienda

    # Scopes
    scope :con_stock, -> { where('cantidad_actual > 0') }
    scope :sin_stock, -> { where(cantidad_actual: 0) }
    scope :stock_bajo, -> { where('cantidad_actual <= cantidad_minima AND cantidad_actual > 0') }
    scope :stock_critico, lambda {
      where('cantidad_actual = 0 OR (cantidad_actual < cantidad_minima AND cantidad_actual <= 1)')
    }
    scope :activos, -> { joins(:producto).where(productos: { discontinued_at: nil }) }

    # Callbacks
    before_validation :set_defaults
    after_update :check_stock_alerts

    def to_s
      "Stock #{producto&.nombre} - #{cantidad_actual}"
    end

    # Stock status methods
    def disponible?
      cantidad_actual.positive?
    end

    def stock_bajo?
      cantidad_actual <= cantidad_minima && cantidad_actual.positive?
    end

    def sin_stock?
      cantidad_actual.zero?
    end

    def stock_critico?
      cantidad_actual.zero? || (cantidad_actual < cantidad_minima && cantidad_actual <= 1)
    end

    def stock_suficiente?(cantidad_requerida)
      cantidad_actual >= cantidad_requerida
    end

    def porcentaje_stock
      return 0 if cantidad_maxima.nil? || cantidad_maxima.zero?

      ((cantidad_actual.to_f / cantidad_maxima) * 100).round(2)
    end

    # Calculate average daily sales over last 90 days (excluding weekends)
    # Returns the maximum between current 90-day average and same month previous year
    # Cached for 24 hours to improve performance
    def promedio_venta_diaria_90_dias
      Rails.cache.fetch("stock_#{id}_promedio_venta_diaria_90_dias", expires_in: 24.hours) do
        # Calculate current 90-day average
        promedio_actual = calcular_promedio_periodo(90.days.ago.to_date, Date.current)

        # Calculate same month previous year average
        mes_actual = Date.current
        inicio_mes_anterior = (mes_actual - 1.year).beginning_of_month
        fin_mes_anterior = (mes_actual - 1.year).end_of_month
        promedio_ano_anterior = calcular_promedio_periodo(inicio_mes_anterior, fin_mes_anterior)

        # Return the maximum of both
        [promedio_actual, promedio_ano_anterior].max
      end
    end

    # Calculate estimated coverage in days based on current stock and daily average sales
    def cobertura_estimada_dias
      promedio = promedio_venta_diaria_90_dias
      return 0 if promedio.zero?

      (cantidad_actual.to_f / promedio).round(0)
    end

    # Calculate recommended minimum stock for 45 days
    def minimo_recomendado_45_dias
      resultado = (45 * promedio_venta_diaria_90_dias).round(0)
      [resultado, 2].max
    end

    # Stock movement methods

    def aumentar_stock(cantidad, motivo = nil, usuario = nil)
      return false if cantidad <= 0

      with_lock do
        reload
        cantidad_anterior = cantidad_actual
        nueva_cantidad = cantidad_actual + cantidad

        update!(cantidad_actual: nueva_cantidad)
        crear_movimiento('entrada', cantidad, motivo, cantidad_anterior, nueva_cantidad, usuario)
      end

      true
    rescue StandardError => e
      errors.add(:base, "Error al aumentar stock: #{e.message}")
      false
    end

    def reducir_stock(cantidad, motivo = nil, usuario = nil)
      return false if cantidad <= 0

      resultado = false

      with_lock do
        reload
        next unless stock_suficiente?(cantidad)

        cantidad_anterior = cantidad_actual
        nueva_cantidad = cantidad_actual - cantidad

        update!(cantidad_actual: nueva_cantidad)
        crear_movimiento('salida', cantidad, motivo, cantidad_anterior, nueva_cantidad, usuario)
        resultado = true
      end

      resultado
    rescue StandardError => e
      errors.add(:base, "Error al reducir stock: #{e.message}")
      false
    end

    def ajustar_stock(nueva_cantidad, motivo = nil, usuario = nil)
      return false if nueva_cantidad.negative?

      with_lock do
        reload
        cantidad_anterior = cantidad_actual
        diferencia = nueva_cantidad - cantidad_anterior

        update!(cantidad_actual: nueva_cantidad)

        if diferencia != 0
          tipo = diferencia.positive? ? 'ajuste_entrada' : 'ajuste_salida'
          crear_movimiento(tipo, diferencia.abs, motivo, cantidad_anterior, nueva_cantidad, usuario)
        end
      end

      true
    rescue StandardError => e
      errors.add(:base, "Error al ajustar stock: #{e.message}")
      false
    end

    # Class methods
    def self.productos_sin_stock(tienda_id, local_id = nil)
      includes(:producto)
        .where(tienda_id: tienda_id, local_id: local_id)
        .sin_stock
        .activos
    end

    def self.productos_stock_bajo(tienda_id, local_id = nil)
      includes(:producto)
        .where(tienda_id: tienda_id, local_id: local_id)
        .stock_bajo
        .activos
    end

    def self.resumen_stock(tienda_id, local_id = nil)
      stocks = where(tienda_id: tienda_id, local_id: local_id).activos

      {
        total_productos: stocks.count,
        con_stock: stocks.con_stock.count,
        sin_stock: stocks.sin_stock.count,
        stock_bajo: stocks.stock_bajo.count,
        stock_critico: stocks.stock_critico.count
      }
    end

    private

    def calcular_promedio_periodo(fecha_inicio, fecha_fin)
      # Get total sold for this producto in the period using a single SQL SUM
      # Only count pedidos that are confirmado (3) or finalizado (4)
      total_vendido = Productos::ProductoSolicitado
                      .joins(:pedido)
                      .where(producto_id: producto_id)
                      .where(pedidos: { tienda_id: tienda_id })
                      .where(pedidos: { fecha: fecha_inicio..fecha_fin })
                      .where(pedidos: { estado_id: [3, 4] })
                      .sum(:cantidad)
                      .to_f

      # Count weekdays mathematically (no iteration)
      dias_laborables = contar_dias_laborables(fecha_inicio, fecha_fin)

      return 0.0 if dias_laborables.zero? || total_vendido.zero?

      # Return average per weekday
      (total_vendido / dias_laborables).round(5)
    end

    def set_defaults
      self.cantidad_actual ||= 0
      self.cantidad_minima ||= 0
      self.tienda_id = producto.tienda_id if producto.present? && tienda_id.blank?
    end

    # Count weekdays mathematically without iterating each date
    def contar_dias_laborables(fecha_inicio, fecha_fin)
      return 0 if fecha_fin < fecha_inicio

      total_dias = (fecha_fin - fecha_inicio).to_i + 1
      semanas_completas = total_dias / 7
      dias_restantes = total_dias % 7

      dias_laborables = semanas_completas * 5

      # Count weekdays in the remaining partial week
      dia_inicio = fecha_inicio.wday
      dias_restantes.times do |i|
        dia = (dia_inicio + i) % 7
        dias_laborables += 1 unless [0, 6].include?(dia)
      end

      dias_laborables
    end

    def cantidad_maxima_mayor_que_minima
      return unless cantidad_maxima.present? && cantidad_minima.present?

      return unless cantidad_maxima <= cantidad_minima

      errors.add(:cantidad_maxima, 'debe ser mayor que la cantidad mínima')
    end

    def producto_pertenece_a_tienda
      return unless producto.present? && tienda_id.present?

      return unless producto.tienda_id != tienda_id

      errors.add(:producto, 'debe pertenecer a la misma tienda')
    end

    def check_stock_alerts
      return unless tienda&.maneja_stock?

      if stock_critico?
        Rails.logger.warn "STOCK CRÍTICO: #{producto.nombre} en #{tienda.nombre} - Cantidad: #{cantidad_actual}"
        # Invalidate dashboard cache so alerts refresh on next page load
        Rails.cache.delete("tienda_#{tienda_id}_stock_alerts")
      elsif stock_bajo?
        Rails.logger.info "STOCK BAJO: #{producto.nombre} en #{tienda.nombre} - Cantidad: #{cantidad_actual}"
        Rails.cache.delete("tienda_#{tienda_id}_stock_alerts")
      end
    end

    def crear_movimiento(tipo, cantidad, motivo, cantidad_anterior = nil, cantidad_nueva = nil, usuario = nil)
      Productos::StockMovimiento.create!(
        stock: self,
        tipo: tipo,
        cantidad: cantidad,
        cantidad_anterior: cantidad_anterior || cantidad_actual,
        cantidad_nueva: cantidad_nueva || cantidad_actual,
        motivo: motivo,
        fecha: Time.current,
        usuario: usuario
      )
    end
  end
end
