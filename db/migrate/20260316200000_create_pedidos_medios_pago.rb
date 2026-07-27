class CreatePedidosMediosPago < ActiveRecord::Migration[7.1]
  def change
    create_table :pedidos_medios_pago do |t|
      t.references :pedido, null: false, foreign_key: { to_table: :pedidos }
      t.string :tipo, null: false
      t.decimal :importe, precision: 12, scale: 2, null: false, default: 0

      t.timestamps
    end
  end
end
