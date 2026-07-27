class Mp4 < ActiveRecord::Migration[5.2]
  def change
    add_column :medios_pago, :pago_electronico_id, :int
    add_index :medios_pago, :pago_electronico_id
  end
end
