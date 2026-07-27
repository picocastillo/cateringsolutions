module Pedidos
  # TurnoEntrega - Gestiona los horarios de entrega de pedidos
  #
  # Lógica de Hora de Corte:
  # ========================
  # - ALMUERZO (codigo: 'almuerzo'):
  #   * Usa el horario_corte_pedidos del cliente
  #   * Si el cliente no tiene horario configurado, usa 11:00 por defecto
  #   * Ejemplo: Cliente con horario_corte_pedidos = '10:30' → usa 10:30
  #
  # - DESAYUNO (codigo: 'desayuno'):
  #   * Usa la hora_corte del turno (07:00)
  #   * Ignora el horario_corte_pedidos del cliente
  #
  # - MERIENDA (codigo: 'merienda'):
  #   * Usa la hora_corte del turno (15:00)
  #   * Ignora el horario_corte_pedidos del cliente
  #
  # Para calcular el próximo día de pedido según turno:
  # @see Clientes::Cliente#proximo_dia_pedido_para_turno
  #
  class TurnoEntrega < ApplicationRecord
    self.table_name = 'turnos_entrega'

    # Associations
    has_many :clientes_turnos_entrega, class_name: 'Pedidos::ClienteTurnoEntrega', dependent: :destroy
    has_many :clientes, through: :clientes_turnos_entrega, source: :cliente

    has_many :turnos_entrega_categorias, class_name: 'Pedidos::TurnoEntregaCategoria', dependent: :destroy
    has_many :categorias_permitidas, through: :turnos_entrega_categorias, source: :categoria, class_name: 'Productos::Categoria'

    has_many :pedidos, class_name: 'Pedidos::Pedido', dependent: :nullify

    # Validations
    validates :nombre, presence: true
    validates :codigo, presence: true, uniqueness: true
    validates :hora_corte, presence: true
    validates :posicion, presence: true, numericality: { only_integer: true }

    # Scopes
    scope :activos, -> { where(activo: true) }
    scope :ordenados, -> { order(:posicion) }

    # Class methods
    def self.por_codigo(codigo)
      find_by(codigo: codigo)
    end

    # Instance methods
    def permite_todas_categorias?
      # Si no tiene restricciones de categorías, permite todas
      turnos_entrega_categorias.empty?
    end

    def permite_categoria?(categoria_id)
      return true if permite_todas_categorias?

      categorias_permitidas.exists?(id: categoria_id)
    end

    def categorias_disponibles_para_tienda(tienda_id)
      if permite_todas_categorias?
        Productos::Categoria.where(tienda_id: tienda_id).active
      else
        categorias_permitidas.where(tienda_id: tienda_id).active
      end
    end

    def productos_disponibles_para_tienda(tienda_id)
      if permite_todas_categorias?
        Productos::Producto.where(tienda_id: tienda_id).active
      else
        categoria_ids = categorias_permitidas.where(tienda_id: tienda_id).active.pluck(:id)
        Productos::Producto.where(tienda_id: tienda_id, categoria_id: categoria_ids).active
      end
    end

    def hora_corte_formateada
      hora_corte.strftime('%H:%M')
    end

    def descripcion_completa
      desc = nombre
      desc += " (#{hora_corte_formateada})"
      desc += " - #{descripcion}" if descripcion.present?
      desc
    end

    def to_s
      nombre
    end
  end
end
