class AddGrupoToCupones < ActiveRecord::Migration[5.2]
  def change
    add_column :cupones, :grupo, :string
    add_index :cupones, :grupo
  end
end
