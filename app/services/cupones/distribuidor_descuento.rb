module Cupones
  class DistribuidorDescuento
    # Distributes a discount proportionally across line items.
    # Uses "last item absorbs remainder" to minimize rounding error.
    #
    # Due to decimal(12,2) per-unit constraint, the maximum unavoidable
    # error is $0.01 when a line's target total doesn't divide evenly
    # by its quantity. Pedido#importe_total compensates by computing
    # subtotal - exact_discount instead of summing per-item prices.
    #
    # @param items [Array] objects responding to #precio_unitario, #cantidad, #precio_con_descuento=
    # @param descuento_total [Numeric] total discount amount
    # @param total [Numeric, nil] pre-calculated sum of precio_unitario * cantidad
    def self.distribuir(items, descuento_total, total = nil)
      total ||= items.sum { |i| i.precio_unitario * i.cantidad }
      return if items.empty? || total.zero? || descuento_total.zero?

      target_total = (total - descuento_total).round(2)
      sum_applied = 0.0

      items.each_with_index do |item, index|
        if index == items.length - 1
          remaining = (target_total - sum_applied).round(2)
          item.precio_con_descuento = (remaining / item.cantidad).round(2)
        else
          proporcion = (item.precio_unitario * item.cantidad) / total
          descuento_unitario = (descuento_total * proporcion / item.cantidad).round(2)
          item.precio_con_descuento = item.precio_unitario - descuento_unitario
          sum_applied += (item.precio_con_descuento * item.cantidad).round(2)
        end
      end
    end
  end
end
