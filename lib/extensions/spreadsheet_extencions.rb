# Permite agregar un array de valores como row a una sheet
class Spreadsheet::Worksheet
  def <<(array)
    @current_row ||= 0
    row(@current_row).replace convert_types array
    @current_row += 1
  end

  def total_row_count
    last_row = detect(&:really_empty?)
    last_row ? last_row.number : row_count - 1
  end

  private

  def convert_types(array)
    array.map do |v|
      case v
      when Danconia::Money, BigDecimal then v.to_f
      when Integer, Float, String then v
      when TrueClass, FalseClass then v.to_sino
      else v.to_s
      end
    end
  end
end

# Permite acceder a los valores de una fila por nombre de columna: row['columna']
class Spreadsheet::Excel::Row
  def [](index)
    value = if index.is_a?(String)
              col = @worksheet.row(0).index(index)
              super(col) if col
            else
              super
            end
    seems_integer(value) ? value.to_i : value
  end

  # Cuando se usa el formato General en Excel, la lib transforma los números siempre a Float, por mas que sea entero.
  # Con esto lo soluciono
  def seems_integer(value)
    return false if !value.respond_to?(:to_i) || value == Float::INFINITY

    value == value.to_i
  end

  def number
    idx + 1
  end

  def really_empty?
    compact.empty?
  end

  def to_hash
    Hash[*@worksheet.row(0).compact.flat_map do |header|
      value = if self[header].is_a?(String)
                self[header].strip
              elsif self[header].nil?
                ''
              else
                self[header]
              end
      [header, value]
    end]
  end
end

class Spreadsheet::Excel::Workbook
  def total_row_count
    worksheets.sum(&:total_row_count)
  end
end
