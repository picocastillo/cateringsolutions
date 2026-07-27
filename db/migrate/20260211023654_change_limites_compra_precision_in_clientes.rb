class ChangeLimitesCompraPrecisionInClientes < ActiveRecord::Migration[5.2]
  def change
    change_column :clientes, :limite_compra_pesos, :decimal, precision: 10, scale: 2
    change_column :clientes, :limite_compra_dolares, :decimal, precision: 10, scale: 2
  end
end
