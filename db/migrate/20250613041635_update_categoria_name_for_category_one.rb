class UpdateCategoriaNameForCategoryOne < ActiveRecord::Migration[5.2]
  def up
    Productos::Producto.where('nombre like ? or nombre like ?', '%300grs%', '%500grs%').where('tienda_id=1').find_each do |producto|
      producto.update_column :nombre, producto.nombre.gsub('300grs.', '').gsub('500grs.', '')
    end
  end
end