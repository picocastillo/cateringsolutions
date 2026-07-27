class DiscontinueProductosTienda3 < ActiveRecord::Migration[7.1]
  CODIGOS = [
    2023, 1293, 1292, 1290, 3049, 1294, 1296, 1297, 1384, 1325,
    1327, 1841, 2687, 1191, 1195, 940, 832, 1346, 2732, 1832,
    1024, 3074, 1440, 1223, 1278, 1280, 1212, 1213, 16, 11,
    1254, 28, 1025, 2878, 897, 898, 580, 2903, 1150, 2973,
    1218, 1222, 2953, 6, 1155, 465, 467, 466, 468, 1310,
    920, 919, 1046, 1045, 476, 304, 306, 305, 439, 383,
    201, 766, 1311, 461, 951, 952, 950, 1207, 707, 3040,
    17, 932
  ].uniq.freeze

  TIENDA_ID = 3

  def up
    productos = Productos::Producto.where(tienda_id: TIENDA_ID, codigo: CODIGOS, discontinued_at: nil)
    found_codigos = productos.pluck(:codigo)
    missing = CODIGOS - found_codigos

    say "Tienda #{TIENDA_ID}: discontinuando #{productos.count} productos (de #{CODIGOS.size} codigos solicitados)"
    say "Faltantes (no encontrados o ya discontinuados): #{missing.inspect}" if missing.any?

    now = Time.current
    productos.update_all(discontinued_at: now, updated_at: now)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
