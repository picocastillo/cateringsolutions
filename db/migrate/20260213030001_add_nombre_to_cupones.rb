class AddNombreToCupones < ActiveRecord::Migration[5.2]
  def change
    add_column :cupones, :nombre, :string
  end
end
