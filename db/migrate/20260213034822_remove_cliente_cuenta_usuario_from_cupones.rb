class RemoveClienteCuentaUsuarioFromCupones < ActiveRecord::Migration[5.2]
  def change
    remove_foreign_key :cupones, :clientes
    remove_foreign_key :cupones, :cuentas
    remove_foreign_key :cupones, :usuarios
    remove_reference :cupones, :cliente, index: true
    remove_reference :cupones, :cuenta, index: true
    remove_reference :cupones, :usuario, index: true
  end
end
