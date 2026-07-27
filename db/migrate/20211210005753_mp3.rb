class Mp3 < ActiveRecord::Migration[5.2]
  def change
    remove_column :pagos_electronicos, :transaction_amount
    remove_column :pagos_electronicos, :transaction_amount_refunded
    remove_column :pagos_electronicos, :coupon_amount
    remove_column :pagos_electronicos, :net_received_amount
    remove_column :pagos_electronicos, :total_paid_amount
    remove_column :pagos_electronicos, :overpaid_amount
    remove_column :pagos_electronicos, :installment_amount

    add_column :pagos_electronicos, :transaction_amount, :decimal, precision: 12, scale: 2
    add_column :pagos_electronicos, :transaction_amount_refunded, :decimal, precision: 12, scale: 2
    add_column :pagos_electronicos, :coupon_amount, :decimal, precision: 12, scale: 2
    add_column :pagos_electronicos, :net_received_amount, :decimal, precision: 12, scale: 2
    add_column :pagos_electronicos, :total_paid_amount, :decimal, precision: 12, scale: 2
    add_column :pagos_electronicos, :overpaid_amount, :decimal, precision: 12, scale: 2
    add_column :pagos_electronicos, :installment_amount, :decimal, precision: 12, scale: 2
  end
end
