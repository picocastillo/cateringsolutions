module Ventas
  module Facturacion
    class Renglon < ApplicationRecord
      self.table_name = 'renglones'

      belongs_to :comprobante, class_name: 'Ventas::Facturacion::Comprobante'
      belongs_to :comprobante_afectado, class_name: 'Ventas::Facturacion::Comprobante', optional: true
      belongs_to :categoria, class_name: 'Productos::Categoria', optional: true
      belongs_to :producto, class_name: 'Productos::Producto', optional: true
      enum :tasa_iva, class_name: 'Impuestos::TasaIva', default: 0
      attr_accessor :cuenta, :plantilla

      money :precio_unitario

      validates :cantidad, numericality: { only_integer: true, greater_than: 0 }
      validates :precio_unitario, numericality: true
      validates :categoria, presence: { message: '^Ítem inválido: Debe seleccionar una categoría.', if: :producto }

      delegate :gravado?, to: :tasa_iva

      defaults cantidad: 1

      Scopes = [:de_categoria].freeze

      before_validation :cachear_categoria

      def self.de_categoria(id)
        where categoria_id: id
      end

      def self.producto_codigo_eq(codigo)
        where producto_id: Productos::Producto.codigo_eq(codigo).map(&:id)
      end

      def producto=(prt)
        super
        self.categoria ||= prt.categoria
      end

      def iva_unitario
        precio_unitario * tasa_iva.alicuota!
      end

      def unitario_con_iva
        precio_unitario + iva_unitario
      end

      def precio_total
        peso.present? ? precio_unitario * cantidad * peso : precio_unitario * cantidad
      end

      def total_con_iva
        precio_total + iva_total
      end

      def iva_total
        precio_total * tasa_iva.alicuota!
      end

      def codigo_facturacion_to_s
        '%08d' % codigo_facturacion
      end

      def clonar
        super(shallow: [:producto, :comprobante_afectado])
      end

      def ajustar_tasa_iva(comprobante)
        self.tasa_iva = :no_gravado if comprobante.no_gravado? || (iva_total.zero? && precio_unitario.positive?)
      end

      def sin_cargo?
        precio_unitario.zero? or cantidad.zero?
      end

      def por_categoria?(categoria)
        precio_base? and self.categoria == categoria
      end

      def usar_descripcion_producto?
        producto
      end

      def origen=(origen)
        super
        cachear_categoria
      end

      def descripcion_ticket
        peso.present? ? "#{producto} #{peso} Kg" : producto.to_s
      end

      def to_console
        format('%-60.60s | %2d | %10.2f', descripcion, cantidad, precio_total)
      end

      def actualizar_precio
        return if !comprobante.pedido || !producto

        precio = producto.buscar_precio(comprobante.pedido.cuenta.cliente, comprobante.pedido.fecha)
        unless precio
          raise ErrorAplicacion,
                "No existe precio de #{producto} para #{comprobante.pedido.cuenta.cliente}."
        end

        self.precio_unitario = precio.importe
      end

      private

      def cachear_categoria
        return unless producto

        self.categoria ||= producto.categoria
      end
    end
  end
end
