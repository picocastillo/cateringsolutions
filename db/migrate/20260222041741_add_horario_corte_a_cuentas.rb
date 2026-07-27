class AddHorarioCorteACuentas < ActiveRecord::Migration[7.1]
  def change
    add_column :cuentas, :horario_corte_pedidos, :string, null: true, default: nil
  end
end
