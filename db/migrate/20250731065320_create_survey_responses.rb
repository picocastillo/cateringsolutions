class CreateSurveyResponses < ActiveRecord::Migration[5.2]
  def change
    create_table :survey_responses do |t|
      t.references :survey, foreign_key: true
      t.references :user, foreign_key: { to_table: :usuarios }
      t.references :tienda, null: false, foreign_key: { to_table: :tiendas }
      t.datetime :completed_at

      t.timestamps
    end
  end
end
