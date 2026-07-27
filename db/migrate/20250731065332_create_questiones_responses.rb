class CreateQuestionesResponses < ActiveRecord::Migration[5.2]
  def change
    create_table :questiones_responses do |t|
      t.references :survey_response, foreign_key: true
      t.references :question, foreign_key: true
      t.references :answer, foreign_key: true
      t.text :response_text

      t.timestamps
    end
  end
end
