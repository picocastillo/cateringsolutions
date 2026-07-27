class AddMedioPagoTipoToPedidos < ActiveRecord::Migration[7.1]
  def change
    add_column :pedidos, :medio_pago_tipo, :string, null: true, default: nil
  end
end
