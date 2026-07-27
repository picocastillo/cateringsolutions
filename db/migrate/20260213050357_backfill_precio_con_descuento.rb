class BackfillPrecioConDescuento < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      UPDATE productos_solicitados
      SET precio_con_descuento = precio_unitario
      WHERE precio_con_descuento IS NULL
    SQL
  end

  def down
    execute <<-SQL
      UPDATE productos_solicitados
      SET precio_con_descuento = NULL
      WHERE precio_con_descuento = precio_unitario
    SQL
  end
end
