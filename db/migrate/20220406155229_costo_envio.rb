class CostoEnvio < ActiveRecord::Migration[5.2]
  def change
    add_column :tiendas, :costo_envio_domicilio, :decimal, precision: 12, scale: 2, default: "0.0", null: false
    Tiendas::Tienda.reset_column_information
    execute "update tiendas set costo_envio_domicilio = 120.0 where id = 1"
    add_column :pedidos, :costo_envio_domicilio, :decimal, precision: 12, scale: 2, default: "0.0", null: false
  end
end
