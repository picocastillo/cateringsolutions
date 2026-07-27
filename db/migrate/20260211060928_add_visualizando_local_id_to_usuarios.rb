class AddVisualizandoLocalIdToUsuarios < ActiveRecord::Migration[5.2]
  def change
    add_column :usuarios, :visualizando_local_id, :bigint
    add_index :usuarios, :visualizando_local_id
  end
end
