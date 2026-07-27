class AddServicioDeImpresionToUsuarios < ActiveRecord::Migration[7.1]
  def change
    add_column :usuarios, :servicio_de_impresion_id, :integer, default: 1, null: false
  end
end
