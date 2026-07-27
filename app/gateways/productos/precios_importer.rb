module Productos
  class PreciosImporter < ExcelImporter
    # Excel serial date epoch: Jan 0, 1900 (with Lotus 1-2-3 leap year bug)
    EXCEL_EPOCH = Date.new(1899, 12, 30)

    def parse_fecha(value)
      return nil if value.blank?
      return value.to_date if value.is_a?(Date) || (value.respond_to?(:to_date) && !value.is_a?(Numeric))

      # Excel serial date number
      EXCEL_EPOCH + value.to_i
    end

    def process_row(row)
      if row['Cuits Clientes'].present?
        clientes = row['Cuits Clientes'].to_s.split(',').map(&:to_i).map { |x| Clientes::Cliente.disponibles_en(autor.tienda_activa).find_by!(cuit: x) }
      end
      if row['Código Producto'].present? && row['Importe'].present?
        producto = Productos::Producto.where(tienda_id: autor.tienda_activa.id).find_by! codigo: row['Código Producto']
        c = row['idPrecio'].blank? ? Productos::Precio.new : Productos::Precio.find(row['idPrecio'].to_i)
        if c.new_record?
          c.producto = producto
          c.clientes = clientes if clientes.present?
          c.importe = row['Importe'].to_f
          c.fecha_desde = parse_fecha(row['Fecha Desde']) if row['Fecha Desde'].present?
          c.fecha_hasta = parse_fecha(row['Fecha Hasta']) if row['Fecha Hasta'].present?
        else
          raise ErrorAplicacion, 'Está intentando cambiar el producto de un precio ya existente.' unless c.producto == producto

          c.clientes = clientes if clientes.present?
          c.fecha_desde = parse_fecha(row['Fecha Desde']) if row['Fecha Desde'].present?
          c.fecha_hasta = parse_fecha(row['Fecha Hasta']) if row['Fecha Hasta'].present?
          c.importe = row['Importe'].to_f if row['Importe'].present?

        end
        if producto && row['Códigos Externos'].present?
          producto.codigos_externos = row['Códigos Externos']
          producto.save!
        end
        c.save!
      else
        cat = Productos::Categoria.where(nombre: row['Categoría'],
                                         tienda_id: autor.tienda_activa.id).first || Productos::Categoria.where(nombre: 'Varios',
                                                                                                                tienda_id: autor.tienda_activa.id).first || Productos::Categoria.create(
                                                                                                                  nombre: 'Varios', tienda: autor.tienda_activa
                                                                                                                )
        precios = if row['Importe'].to_f.positive?
                    [Productos::Precio.create(fecha_desde: 1.day.ago, importe: row['Importe'].to_f)]
                  else
                    []
                  end
        Productos::Producto.create(tienda: autor.tienda_activa, nombre: row['Producto'],
                                   codigos_externos: row['Códigos Externos'].presence,
                                   codigo: row['Código Pesable'].presence,
                                   categoria: cat, precios: precios)
      end
    end
  end
end
