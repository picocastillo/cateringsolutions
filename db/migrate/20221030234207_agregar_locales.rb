class AgregarLocales < ActiveRecord::Migration[5.2]
  def change
    add_column :pedidos, :local_id, :integer
    add_index :pedidos, :local_id

    add_column :usuarios, :local_id, :integer
    add_index :usuarios, :local_id
    create_table "locales" do |t|
      t.string "nombre"
      t.string "domicilio"
      t.string "telefono"
      t.integer "tienda_id"
    end
    add_index :locales, :nombre
    add_index :locales, :tienda_id
    add_column :tiendas, :multiple_locales, :boolean, default: false
    add_column :comprobantes, :local_id, :integer
    add_index :comprobantes, :local_id
    Tiendas::Tienda.reset_column_information
    execute "update tiendas set multiple_locales = true where id = 2"
    Locales::Local.create! nombre: 'Tivoglio La Tienda', domicilio: 'Hipólito Vieytes 169', telefono: '+543492573075', tienda_id: 2
    Locales::Local.create! nombre: 'Tivoglio', domicilio: '3 de Febrero 123', telefono: '+543492573075', tienda_id: 2
    Comprobantes::Comprobante.reset_column_information
    Ventas::Facturacion::Comprobante.where(tienda_id: 2).update_all(local_id: 1)
    Pedidos::Pedido.where(tienda_id: 2).update_all(local_id: 1)
  end
end