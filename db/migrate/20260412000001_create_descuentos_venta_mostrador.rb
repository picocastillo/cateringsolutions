class CreateDescuentosVentaMostrador < ActiveRecord::Migration[7.1]
  def change
    create_table :descuentos_venta_mostrador, charset: 'latin1', collation: 'latin1_swedish_ci' do |t|
      t.bigint :tienda_id, null: false
      t.string :nombre, null: false
      t.string :tipo_descuento, null: false, default: 'porcentaje'
      t.decimal :porcentaje, precision: 5, scale: 2
      t.decimal :importe, precision: 12, scale: 2
      t.decimal :limite_bonificacion, precision: 12, scale: 2
      t.string :medio_pago_tipo, null: false
      t.decimal :importe_minimo, precision: 12, scale: 2, null: false, default: 0
      t.boolean :activo, default: true, null: false
      t.timestamps
    end

    add_index :descuentos_venta_mostrador, :tienda_id
    add_index :descuentos_venta_mostrador, :activo
    add_index :descuentos_venta_mostrador, :medio_pago_tipo
    add_foreign_key :descuentos_venta_mostrador, :tiendas

    create_table :descuentos_venta_mostrador_clientes, id: false, charset: 'latin1', collation: 'latin1_swedish_ci' do |t|
      t.bigint :descuento_venta_mostrador_id, null: false
      t.bigint :cliente_id, null: false
    end

    add_index :descuentos_venta_mostrador_clientes, [:descuento_venta_mostrador_id, :cliente_id],
              unique: true, name: 'idx_descuentos_vm_clientes_unique'
    add_index :descuentos_venta_mostrador_clientes, :cliente_id, name: 'idx_descuentos_vm_cliente_id'
    add_foreign_key :descuentos_venta_mostrador_clientes, :descuentos_venta_mostrador
    add_foreign_key :descuentos_venta_mostrador_clientes, :clientes

    add_reference :pedidos, :descuento_venta_mostrador,
                  foreign_key: { to_table: :descuentos_venta_mostrador }, null: true
  end
end
