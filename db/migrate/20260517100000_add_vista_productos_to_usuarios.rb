class AddVistaProductosToUsuarios < ActiveRecord::Migration[7.1]
  def change
    add_column :usuarios, :vista_productos, :string, default: 'pasadores', null: false
  end
end
