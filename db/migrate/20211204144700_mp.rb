class Mp < ActiveRecord::Migration[5.2]
  def change
    add_column :pedidos, :merchant_order_id, :string
    add_column :pedidos, :payment_id, :string
    unless Rails.env.development?
      add_column :pedidos, :confirmation_token, :string, limit: 26
      add_index :pedidos, :confirmation_token
    end
    add_column :clientes, :cuenta_corriente, :boolean, default: true
    add_column :pedidos, :cobrado, :boolean, default: false
  end
end
