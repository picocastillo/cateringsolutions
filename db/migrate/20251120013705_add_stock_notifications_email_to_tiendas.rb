class AddStockNotificationsEmailToTiendas < ActiveRecord::Migration[5.2]
  def change
    add_column :tiendas, :stock_notifications_email, :string
  end
end
