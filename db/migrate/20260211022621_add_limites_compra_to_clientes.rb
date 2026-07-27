class AddLimitesCompraToClientes < ActiveRecord::Migration[5.2]
  def change
    add_column :clientes, :limite_compra_pesos, :decimal
    add_column :clientes, :limite_compra_dolares, :decimal
  end
end
