class AddVentaMostradorCompositeIndexToPedidos < ActiveRecord::Migration[7.1]
  def change
    add_index :pedidos, [:tienda_id, :venta_mostrador, :fecha, :codigo],
              name: 'idx_pedidos_tienda_vm_fecha_codigo'
  end
end
