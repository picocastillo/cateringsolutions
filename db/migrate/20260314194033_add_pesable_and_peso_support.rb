class AddPesableAndPesoSupport < ActiveRecord::Migration[7.1]
  def change
    add_column :productos, :pesable, :boolean, default: false, null: false
    add_column :productos_solicitados, :peso, :decimal, precision: 10, scale: 3
    add_column :renglones, :peso, :decimal, precision: 10, scale: 3
  end
end
