class CreateAnsweres < ActiveRecord::Migration[5.2]
  def change
    create_table :answeres do |t|
      t.references :question, foreign_key: true
      t.string :text
      t.string :value

      t.timestamps
    end
  end
end
