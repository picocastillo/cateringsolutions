class CreateCotizacionesDolar < ActiveRecord::Migration[7.1]
  def change
    create_table :cotizaciones_dolar do |t|
      t.date :fecha, null: false
      t.decimal :precio_venta, precision: 10, scale: 2, null: false
      t.decimal :precio_compra, precision: 10, scale: 2
      t.string :fuente, default: 'oficial', null: false

      t.timestamps
    end

    add_index :cotizaciones_dolar, :fecha, unique: true
  end
end
