class MultipleMenuDiarios < ActiveRecord::Migration[5.2]
  def change
    create_table "menus_diarios_productos", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1", force: :cascade do |t|
      t.integer "menu_diario_id"
      t.integer "producto_id"
      t.index ["menu_diario_id"], name: "index_menus_diarios_productos_on_menu_diario_id"
      t.index ["producto_id"], name: "index_menus_diarios_productos_on_producto_id"
    end
    execute "insert into menus_diarios_productos (menu_diario_id, producto_id) select id, producto_id from menus_diarios order by id asc"
    remove_column :menus_diarios, :producto_id
    
    calorico, saludable, vegetariano = Productos::Producto.find(1), Productos::Producto.find(2), Productos::Producto.find(3)
    [calorico, saludable, vegetariano ].each { |x| x.descripcion = '500 grs'; x.save! }

    md = Productos::Categoria.where(nombre: 'Menús del Dia', tienda_id: 1).first
    mini_calorico = Productos::Producto.new(nombre: 'Mini Menú Calórico', descripcion: '300 grs', tienda_id: 1, categoria_id: md.id)
    mini_calorico.save!
    mini_saludable = Productos::Producto.new(nombre: 'Mini Menú Saludable', descripcion: '300 grs', tienda_id: 1, categoria_id: md.id)
    mini_saludable.save!
    mini_vegetariano = Productos::Producto.new(nombre: 'Mini Menú Veggie', descripcion: '300 grs', tienda_id: 1, categoria_id: md.id)
    mini_vegetariano.save!

    MenusDiarios::MenuDiario.where('fecha > ?', Time.zone.today).find_each do |m|
      m.productos << mini_calorico if m.productos.first == calorico
      m.productos << mini_saludable if m.productos.first == saludable
      m.productos << mini_vegetariano if m.productos.first == vegetariano
    end
  end
end
