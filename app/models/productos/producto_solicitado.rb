module Productos
  class ProductoSolicitado < ApplicationRecord
    acts_as_discontinued
    belongs_to :pedido, class_name: 'Pedidos::Pedido'
    belongs_to :producto, class_name: 'Productos::Producto'
    belongs_to :menu_diario, class_name: 'MenusDiarios::MenuDiario', optional: true

    validates :cantidad, :precio_unitario, presence: true
    validates :cantidad, numericality: { greater_than: 0, less_than: 1000 }
    validates :peso, numericality: { greater_than: 0 }, allow_nil: true

    before_validation :asignar_precio
    before_save :sincronizar_precio_con_descuento
    validate :pedido_must_be_pendiente_for_changes, on: :update

    def to_s
      cant = if cantidad.to_i.positive?
               if peso.present?
                 "<div>#{peso} Kg X #{importe_total}</div>"
               else
                 "<div>#{cantidad} Un. X #{importe_total}</div>"
               end
             end
      "#{nombre_carrito}#{cant}".html_safe
    end

    def to_growl
      cant = if cantidad.to_i.positive?
               if peso.present?
                 "<div>#{peso} Kg X #{importe_total}</div>"
               else
                 "<div>#{cantidad} Un. X #{importe_total}</div>"
               end
             end
      "#{nombre_carrito.truncate(32)}#{cant}".html_safe
    end

    def nombre_carrito
      menu_diario.present? ? "#{producto}: #{menu_diario.descripcion}" : producto.to_s
    end

    def nombre_y_precio
      n = menu_diario.present? ? "#{producto} - #{menu_diario.descripcion.capitalize}" : producto.to_s
      "#{n}: #{Danconia::Money.new(precio_efectivo)}"
    end

    def nombre_codigos_y_precio
      ce = if producto.codigos_externos.present?
             "<span style='color: #aaa;margin-left:15px' title='Códigos Externos'>CE</span> " \
               "#{producto.codigos_externos} "
           else
             ''
           end
      c = " <span style='color: #aaa;' title='Código'>C</span> #{producto.codigo}"
      n = menu_diario.present? ? "#{producto} - #{menu_diario.descripcion.capitalize}" : producto.to_s
      "<div class='row'><div class='col-sm-7 col-md-7'>#{n}</div>" \
        "<div class='col-sm-3 col-md-3' style='text-align:right'>#{c}#{ce}</div>" \
        "<div class='col-sm-2 col-md-2' style='text-align:right'>#{Danconia::Money.new(precio_efectivo)}</div>"
    end

    def codigo_de_barras
      "#{pedido.codigo}-#{producto.codigo}"
    end

    def sin_importes
      cant = if cantidad.to_i.positive?
               peso.present? ? "#{peso} Kg " : "#{cantidad} x "
             end
      "#{cant}#{nombre_carrito}"
    end

    def sin_producto
      return unless cantidad.to_i.positive?

      peso.present? ? "#{peso} Kg X #{Danconia::Money.new(precio_efectivo)}" : "#{cantidad} X #{Danconia::Money.new(precio_efectivo)}"
    end

    def precio_efectivo
      precio_con_descuento || precio_unitario
    end

    def tiene_descuento?
      precio_con_descuento.present? && precio_con_descuento < precio_unitario
    end

    def importe_total
      return unless precio_unitario

      if peso.present?
        Danconia::Money.new(cantidad * peso * precio_efectivo)
      else
        Danconia::Money.new(cantidad * precio_efectivo)
      end
    end

    def importe_total_sin_descuento
      return unless precio_unitario

      if peso.present?
        Danconia::Money.new(cantidad * peso * precio_unitario)
      else
        Danconia::Money.new(cantidad * precio_unitario)
      end
    end

    def peso_total
      return if peso.blank?

      cantidad * peso
    end

    def precio_por_unidad
      Danconia::Money.new(precio_unitario)
    end

    def actualizar_precio
      return if destroyed?

      if producto.categoria.menu_diario && (md = producto.menus_diarios.where(menus_diarios: { fecha: pedido.fecha,
                                                                                               tipo_id: ::MenusDiarios::Tipo[:menu_diario].id }).first)
        self.menu_diario = md
      end
      if pedido.cuenta
        precio = producto.buscar_precio(pedido.cuenta.cliente, pedido.fecha)
      else
        errors.add :precio_unitario, 'Debe elegir cliente o cuenta para el pedido.'
      end
      errors.add :precio_unitario, "No existe precio de #{producto} para #{pedido.cuenta&.cliente}." unless precio
      self.precio_unitario = precio.importe if precio
    end

    private

    def asignar_precio
      return unless pedido.pendiente? && !pesable? && !pedido.cargando_inicial?

      actualizar_precio
    end

    def sincronizar_precio_con_descuento
      return unless pedido&.pendiente?
      return unless precio_con_descuento.nil? || (precio_unitario_changed? && !precio_con_descuento_changed?)

      self.precio_con_descuento = precio_unitario
    end

    # Bug B guard: once a pedido is past pendiente (aceptado/confirmado/finalizado),
    # productos_solicitados drive a confirmed factura's renglones. Mutating them
    # silently drifts ps_total from ventas_net without a corresponding NC. Block
    # updates entirely; cancellation should go through Pedido#cancelar! which
    # creates the NC.
    def pedido_must_be_pendiente_for_changes
      return if pedido.nil? || pedido.pendiente?
      return unless cantidad_changed? || precio_unitario_changed? ||
                    precio_con_descuento_changed? || peso_changed? || producto_id_changed?

      errors.add :pedido, 'debe estar pendiente para modificar productos solicitados'
    end
  end
end
