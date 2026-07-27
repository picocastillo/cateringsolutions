class SetVistaListaDefaultForAllUsers < ActiveRecord::Migration[7.1]
  def up
    change_column_default :usuarios, :vista_productos, from: 'pasadores', to: 'lista'
    Usuarios::Usuario.update_all(vista_productos: 'lista')
  end

  def down
    change_column_default :usuarios, :vista_productos, from: 'lista', to: 'pasadores'
  end
end
