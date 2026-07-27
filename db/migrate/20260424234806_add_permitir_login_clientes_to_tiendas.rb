class AddPermitirLoginClientesToTiendas < ActiveRecord::Migration[7.1]
  def change
    add_column :tiendas, :permitir_login_clientes, :boolean, default: true, null: false
  end
end
