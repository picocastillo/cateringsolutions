class AddMovimientosCblesCompositeIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :movimientos_cbles, [:tienda_id, :cuenta_id, :indice],
              name: 'idx_movimientos_tienda_cuenta_indice'
  end
end
