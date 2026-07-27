class AllowCuentaOwnerOnPedidoMultiple < ActiveRecord::Migration[7.1]
  def change
    # Allow groups owned by a cuenta instead of (or in addition to) a usuario.
    change_column_null :pedidos_multiples, :usuario_id, true
    add_reference :pedidos_multiples, :cuenta,
                  null: true, foreign_key: { to_table: :cuentas }
  end
end
