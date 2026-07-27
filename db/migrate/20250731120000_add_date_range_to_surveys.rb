class AddDateRangeToSurveys < ActiveRecord::Migration[5.2]
  def change
    add_column :surveys, :fecha_desde, :date
    add_column :surveys, :fecha_hasta, :date
  end
end
