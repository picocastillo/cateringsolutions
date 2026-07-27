class FixDescuentoVmColumns < ActiveRecord::Migration[7.1]
  def change
    change_column_default :descuentos_venta_mostrador, :medio_pago_tipo, ''
    add_column :pedidos, :monto_descuento_vm, :decimal, precision: 12, scale: 2
  end
end
