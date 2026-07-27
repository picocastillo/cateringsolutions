class Mp2 < ActiveRecord::Migration[5.2]
  def change
    create_table "pagos_electronicos" do |t|
      t.integer :pedido_id, index: true
      t.integer :position, index: true
      t.bigint "pago_id", index: true
      t.datetime "date_created"
      t.datetime "date_approved"
      t.datetime "date_last_updated"
      t.datetime "money_release_date"
      t.string "payment_method_id"
      t.string "payment_type_id"
      t.string "status"
      t.string "status_detail"
      t.string "currency_id"
      t.string "description"
      t.bigint "collector_id"
      t.bigint "order_id"
      t.integer "installments", null: false, default: 1
      t.decimal "transaction_amount", precision: 12, scale: 2, default: "0.0", null: false
      t.decimal "transaction_amount_refunded", precision: 12, scale: 2, default: "0.0", null: false
      t.decimal "coupon_amount", precision: 12, scale: 2, default: "0.0", null: false
      t.decimal "net_received_amount", precision: 12, scale: 2, default: "0.0", null: false
      t.decimal "total_paid_amount", precision: 12, scale: 2, default: "0.0", null: false
      t.decimal "overpaid_amount", precision: 12, scale: 2, default: "0.0", null: false
      t.decimal "installment_amount", precision: 12, scale: 2, default: "0.0", null: false
    end
    Pedidos::Pedido.where('payment_id is not null').find_each do |x|
      Pedidos::MercadopagoUpdaterJob.perform_later x.payment_id
    end
    remove_column :pedidos, :merchant_order_id, :string
    remove_column :pedidos, :payment_id, :string
  end
end
