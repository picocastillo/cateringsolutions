class CreateSurveys < ActiveRecord::Migration[5.2]
  def change
    create_table :surveys do |t|
      t.string :title
      t.text :description
      t.boolean :active
      t.references :tienda, null: false, foreign_key: { to_table: :tiendas }

      t.timestamps
    end
  end
end
