module VentasMostrador
  class DescuentoVentaMostrador < ApplicationRecord
    self.table_name = 'descuentos_venta_mostrador'

    belongs_to :tienda, class_name: 'Tiendas::Tienda'
    has_and_belongs_to_many :clientes, class_name: 'Clientes::Cliente',
                                       join_table: 'descuentos_venta_mostrador_clientes'
    has_many :pedidos, class_name: 'Pedidos::Pedido', dependent: :nullify

    validates :nombre, presence: true
    validates :tipo_descuento, presence: true, inclusion: { in: ['importe', 'porcentaje'] }
    validates :medio_pago_tipo, inclusion: { in: Pedidos::MedioPago::TIPOS.keys }, allow_blank: true
    validates :importe_minimo, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :importe, presence: true, numericality: { greater_than: 0 }, if: -> { tipo_descuento == 'importe' }
    validates :porcentaje, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 },
                           if: -> { tipo_descuento == 'porcentaje' }
    validates :limite_bonificacion, presence: true, numericality: { greater_than: 0 },
                                    if: -> { tipo_descuento == 'porcentaje' }

    scope :activos, -> { where(activo: true) }

    def to_s
      nombre
    end

    # Returns the discount amount.
    # When +importe_medio+ is given AND the discount targets a specific medio,
    # the discount base is the medio's importe (not the product total).
    # When +medio_pago_tipo+ is blank ("Todos"), the base is always +importe_total+.
    def descuento_para(importe_total, importe_medio: nil)
      base = medio_pago_tipo.present? && importe_medio ? importe_medio : importe_total
      if tipo_descuento == 'importe'
        [importe, base].min
      else
        [base * porcentaje / 100.0, limite_bonificacion || Float::INFINITY].min
      end
    end

    def descuento_descripcion
      if tipo_descuento == 'importe'
        "$#{importe.to_i == importe ? importe.to_i : importe}"
      else
        pct = porcentaje.to_i == porcentaje ? porcentaje.to_i : porcentaje
        "#{pct}%"
      end
    end

    def limite_bonificacion_descripcion
      return unless tipo_descuento == 'porcentaje' && limite_bonificacion.present?

      lim = limite_bonificacion.to_i == limite_bonificacion ? limite_bonificacion.to_i : limite_bonificacion
      "$#{lim}"
    end

    def medio_pago_label
      medio_pago_tipo.present? ? (Pedidos::MedioPago::TIPOS[medio_pago_tipo] || medio_pago_tipo) : 'Todos'
    end

    def aplicable_a_cliente?(cliente)
      clientes.empty? || clientes.exists?(id: cliente&.id)
    end

    def aplicable?(medio_pago_tipo:, importe_total:, cliente: nil)
      activo? &&
        (self.medio_pago_tipo.blank? || self.medio_pago_tipo == medio_pago_tipo) &&
        importe_total >= importe_minimo &&
        aplicable_a_cliente?(cliente)
    end

    # Returns the single DescuentoVentaMostrador giving the highest absolute discount, or nil.
    # +importe_medio+: the importe of the dominant medio de pago.
    # Medio-specific discounts use it as their base; "todos" discounts use +importe_total+.
    def self.mejor_descuento_para(tienda:, cliente:, medio_pago_tipo:, importe_total:, importe_medio: nil)
      candidatos = activos.where(tienda: tienda)
                          .where('medio_pago_tipo = ? OR medio_pago_tipo IS NULL OR medio_pago_tipo = ?',
                                 medio_pago_tipo, '')
                          .where(importe_minimo: ..importe_total)

      mejor = nil
      mejor_monto = 0

      candidatos.includes(:clientes).find_each do |d|
        next unless d.aplicable_a_cliente?(cliente)

        monto = d.descuento_para(importe_total, importe_medio: importe_medio)
        if monto > mejor_monto
          mejor = d
          mejor_monto = monto
        end
      end

      mejor
    end
  end
end
