class ExcelExporter < Exporter
  require 'write_xlsx'

  before_save :process_params

  def rows(objeto)
    respond_to?(:record) ? [record(objeto).values] : [row(objeto)]
  end

  def run(objects)
    preparar_adjunto filename
    @current_row = 0
    @workbook = WriteXLSX.new(xlsx_filepath, optimization: true)
    setup_formats
    sheet = @workbook.add_worksheet
    write_sheet sheet, objects
    @workbook.close
    make_zip if zippear?
  end

  def write_sheet(sheet, objects)
    write_table sheet, objects
  end

  def write_table(sheet, objects)
    crear_encabezados sheet, objects
    each_object_con_progreso_y_cancelacion objects do |object|
      rows(object).each do |r|
        write_row sheet, r if r
      end
    end
    crear_footers sheet, objects
  end

  def each_object_con_progreso_y_cancelacion(objects)
    ActiveRecord::Base.cache do
      enumerable(objects).each do |item|
        break if progreso.fue_cancelado?

        yield item
        progreso.avanzar
      end
    end
  rescue StandardError => e
    progreso.finish_with_error e.message
    raise e
  end

  def enumerable(objects)
    objects.each_record_in_ordered_batches batch_size: 500
  end

  def write_row(sheet, array, format = nil)
    converted = convert_types(array)
    converted.each_with_index do |val, col|
      cell_fmt = format || (@column_formats && @column_formats[col])
      sheet.write(@current_row, col, val, cell_fmt)
    end
    @current_row += 1
  end

  def xlsx_filepath
    filepath.sub('.zip', '.xlsx')
  end

  # Subclasses override to set @column_formats = { col_index => format }
  def setup_column_formats; end

  private

  def setup_formats
    @header_format = @workbook.add_format(bold: true, color: 'black')
    @currency_format = @workbook.add_format(num_format: '$#,##0.00')
    @total_currency = @workbook.add_format(num_format: '$#,##0.00', bold: true, color: 'black')
    @percent_format = @workbook.add_format(num_format: '0.0%')
    @date_format = @workbook.add_format(num_format: 'DD/MM/YYYY')
    setup_column_formats
  end

  def crear_encabezados(sheet, objects)
    hs = if respond_to?(:headers)
           headers
         else
           objects.first ? record(objects.first).keys : ['No se encontraron resultados.']
         end
    write_row sheet, hs, @header_format
  end

  def crear_footers(sheet, _objects)
    return unless respond_to?(:footers)

    if footers.is_a?(Array) && footers.first.is_a?(Array)
      footers.each do |f|
        write_row sheet, f, @header_format
      end
    else
      write_row sheet, footers, @header_format
    end
  end

  def filename
    ext = zippear? ? 'zip' : 'xlsx'
    "#{filename_prefix}_#{Time.zone.today.to_s(:file)}.#{ext}"
  end

  def filename_prefix
    name.underscore
  end

  def name
    self.class.name.sub('Exporter', '')
  end

  def modelclass
    name.singularize.constantize
  end

  def modelclass_name
    modelclass.name.demodulize
  end

  def make_zip
    system 'zip', '-9jqm', filepath, xlsx_filepath
  end

  def convert_types(array)
    array.map do |v|
      case v
      when Danconia::Money, BigDecimal then v.to_f
      when Integer, Float, String, Date then v
      when TrueClass, FalseClass then v.to_sino
      when Time, DateTime then v.to_date
      when NilClass then ''
      else v.to_s
      end
    end
  end

  def process_params
    self.params = params.deep_symbolize_keys if params.is_a?(Hash)
    params[:zippear] = true unless params.key?(:zippear)
  end

  def zippear?
    false
  end
end
