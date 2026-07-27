class AddAceptadoFieldsToPedidos < ActiveRecord::Migration[7.1]
  def change
    add_column :pedidos, :aceptado_el, :datetime
    add_column :pedidos, :aceptado_por_id, :integer
  end
end
