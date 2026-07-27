module Productos
  class StocksImporter < ExcelImporter
    def process_row(row)
      # Find or create stock record
      stock = if row['ID'].present?
                Productos::Stock.find(row['ID'])
              else
                find_or_initialize_stock(row)
              end

      # Update stock quantities
      if row['Cantidad Actual'].present?
        nueva_cantidad = row['Cantidad Actual'].to_i
        if stock.persisted? && stock.cantidad_actual != nueva_cantidad
          # Use ajustar_stock to track the change
          motivo = "Importación Excel - #{Time.current.strftime('%d/%m/%Y %H:%M')}"
          stock.ajustar_stock(nueva_cantidad, motivo, autor)
        else
          stock.cantidad_actual = nueva_cantidad
        end
      end

      stock.cantidad_minima = row['Cantidad Mínima'].to_i if row['Cantidad Mínima'].present?

      stock.cantidad_maxima = row['Cantidad Máxima'].to_i if row.key?('Cantidad Máxima') && row['Cantidad Máxima'].present?

      stock.activo = Boolean(row['Activo']) if row['Activo'].present?

      # Save if it's a new record (existing records already saved via ajustar_stock)
      stock.save! if stock.new_record? || stock.changed?
    end

    private

    def find_or_initialize_stock(row)
      # Validate required fields
      raise ErrorAplicacion, 'Producto es requerido' unless row['Producto'].present? || row['Código'].present?

      # Use current user's tienda - check BEFORE searching for producto
      tienda = autor.tienda_activa
      raise ErrorAplicacion, 'No se puede determinar la tienda activa del usuario' unless tienda

      # Find producto by name or code
      producto = find_producto(row)
      raise ErrorAplicacion, "No se encontró el producto: #{row['Producto'] || row['Código']}" unless producto

      # Validate producto belongs to tienda (redundant with scoped search, but explicit safety check)
      raise ErrorAplicacion, 'El producto no pertenece a la tienda especificada' if producto.tienda_id != tienda.id

      # Local is always nil (main stock only)
      local = nil

      # Find or initialize stock
      stock = Productos::Stock.find_or_initialize_by(
        producto_id: producto.id,
        tienda_id: tienda.id,
        local_id: local&.id
      )

      # Set defaults for new records
      if stock.new_record?
        stock.cantidad_actual = 0
        stock.cantidad_minima = 0
        stock.activo = true
      end

      stock
    end

    def find_producto(row)
      tienda = autor.tienda_activa

      # Try by exact code first (scoped to tienda)
      if row['Código'].present?
        producto = Productos::Producto.find_by(codigo: row['Código'].to_s.strip, tienda_id: tienda&.id)
        return producto if producto
      end

      # Try by exact name (scoped to tienda)
      if row['Producto'].present?
        nombre = row['Producto'].strip
        producto = Productos::Producto.find_by(nombre: nombre, tienda_id: tienda&.id)
        return producto if producto

        # Fall back to LIKE search (scoped to tienda)
        producto = Productos::Producto.where(tienda_id: tienda&.id)
                                      .where('nombre LIKE ?', "%#{nombre}%")
                                      .order(:nombre)
                                      .first
        return producto if producto
      end

      nil
    end
  end
end
