class CreateCupones < ActiveRecord::Migration[5.2]
  def change
    create_table :cupones do |t|
      t.string :codigo, null: false
      t.references :tienda, foreign_key: { to_table: :tiendas }
      t.references :cliente, foreign_key: { to_table: :clientes }
      t.references :cuenta, foreign_key: { to_table: :cuentas }
      t.references :usuario, foreign_key: { to_table: :usuarios }
      t.string :tipo_descuento, null: false, default: 'importe'
      t.decimal :importe, precision: 10, scale: 2
      t.decimal :porcentaje, precision: 5, scale: 2
      t.decimal :limite_bonificacion, precision: 10, scale: 2
      t.date :fecha_vencimiento
      t.boolean :utilizado, default: false, null: false
      t.timestamps
    end

    add_index :cupones, :codigo, unique: true
    add_index :cupones, :fecha_vencimiento
    add_index :cupones, :utilizado
  end
end
