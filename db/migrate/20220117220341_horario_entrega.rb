class HorarioEntrega < ActiveRecord::Migration[5.2]
  def change
    unless Rails.env.development?
      create_table "horarios" do |t|
        t.integer :position
        t.integer :tienda_id
        t.string "horario"
        t.string "nombre"
        t.boolean :predeterminado, null: false, default: false
        t.datetime :discontinued_at
      end
      add_index :horarios, :position
      add_index :horarios, :tienda_id
      add_index :horarios, :discontinued_at
      add_column :pedidos, :horario_id, :integer
      add_index :pedidos, :horario_id
      add_column :tiendas, :horarios_de_entrega, :boolean, default: false
      add_column :clientes, :horarios_de_entrega, :boolean, default: false
      Tiendas::Tienda.reset_column_information
      Clientes::Cliente.reset_column_information
      execute "update tiendas set horarios_de_entrega = true where id = 1"
      execute "update pedidos set horario_id = 1 where tienda_id = 1 and estado_id <> 1"
      Pedidos::Horario.create! nombre: 'Mañana', horario: '12:30hs', tienda_id: 1, predeterminado: true
      Pedidos::Horario.create! nombre: 'Tarde', horario: '19:00hs', tienda_id: 1
    end
  end
end
