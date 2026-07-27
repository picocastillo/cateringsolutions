class AddCuentaCorrienteParcialToCuentas < ActiveRecord::Migration[5.2]
  def change
    add_column :cuentas, :cuenta_corriente_parcial, :boolean, default: true
  end
end
