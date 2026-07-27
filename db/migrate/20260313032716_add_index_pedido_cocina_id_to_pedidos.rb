class AddIndexPedidoCocinaIdToPedidos < ActiveRecord::Migration[7.1]
  def change
    add_index :pedidos, :pedido_cocina_id, name: 'index_pedidos_on_pedido_cocina_id'
  end
end
