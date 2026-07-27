class CreateQuestiones < ActiveRecord::Migration[5.2]
  def change
    create_table :questiones do |t|
      t.references :survey, foreign_key: true
      t.text :text
      t.string :question_type
      t.boolean :required

      t.timestamps
    end
  end
end
