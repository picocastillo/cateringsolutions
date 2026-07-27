class FixPedido674355Cantidad < ActiveRecord::Migration[7.1]
  # Pedido 674355 had producto_solicitado 833659 (producto 6361) with cantidad=7
  # while every other line in the same pedido (and the cliente's pattern) is 4.
  # Same dup race that motivated the previous dedupe migration left this one
  # outlier behind. Bring the PS and its renglon back to 4 and recompute the
  # factura total / subtotal.
  def up
    ps_id      = 833_659
    renglon_id = 809_118
    comp_id    = 653_281
    sub_id     = 1_059_580
    nuevo_total = BigDecimal('4') * BigDecimal('7591.19') + BigDecimal('4') * BigDecimal('1807.41')

    execute "UPDATE productos_solicitados SET cantidad = 4 WHERE id = #{ps_id} AND cantidad = 7"
    execute "UPDATE renglones SET cantidad = 4 WHERE id = #{renglon_id} AND cantidad = 7"
    execute "UPDATE comprobantes SET total = #{nuevo_total.to_s('F')} WHERE id = #{comp_id}"
    execute "UPDATE subtotales SET base_imponible = #{nuevo_total.to_s('F')} WHERE id = #{sub_id}"
  end

  def down
    # Not reversible: prior cantidad=7 was incorrect data.
  end
end
