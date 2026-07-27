class GrupoCocina < ActiveRecord::Migration[5.2]
  def change
    create_table "grupos_cocinas", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
      t.string "nombre"
      t.integer "codigo"
      t.string "descripcion"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "tienda_id"
      t.index ["codigo"], name: "index_categorias_on_codigo"
      t.index ["nombre"], name: "index_categorias_on_nombre"
      t.index ["tienda_id"], name: "index_categorias_on_tienda_id"
    end

    add_column :categorias, :grupo_cocina_id, :integer
  end
end
