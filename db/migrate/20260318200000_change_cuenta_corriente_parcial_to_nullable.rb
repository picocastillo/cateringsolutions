class ChangeCuentaCorrienteParcialToNullable < ActiveRecord::Migration[7.1]
  def up
    # Change default to nil and allow NULL (nil = inherit from cliente)
    change_column_default :cuentas, :cuenta_corriente_parcial, from: true, to: nil

    # Migrate existing true values to nil (they were the default, not explicit overrides)
    # Keep false values as-is (those were explicitly disabled)
    execute "UPDATE cuentas SET cuenta_corriente_parcial = NULL WHERE cuenta_corriente_parcial = 1"
  end

  def down
    execute "UPDATE cuentas SET cuenta_corriente_parcial = 1 WHERE cuenta_corriente_parcial IS NULL"
    change_column_default :cuentas, :cuenta_corriente_parcial, from: nil, to: true
  end
end
