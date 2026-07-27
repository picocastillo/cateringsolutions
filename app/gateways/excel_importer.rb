class ExcelImporter < Infraestructura::Procesos::Proceso
  attr_reader :headers
  attr_writer :row_num

  validates_format_of :adjunto_file_name, with: /\.xlsx\z/i, message: '^Solo se permiten archivos Excel en formato .xlsx (no se aceptan archivos .xls)'
  do_not_validate_attachment_file_type :adjunto

  def perform
    run adjunto.path
  rescue StandardError => e
    progreso.finish_with_error e.message
    Notify.exception e
    raise e
  end

  def run(file)
    spreadsheet = open_spreadsheet(file)
    sheet = spreadsheet.sheet(0)
    total_rows = sheet.last_row ? sheet.last_row - 1 : 0
    progreso.track total_rows do
      @headers = sheet.row(1).map { |h| h.to_s.strip }
      before_process
      (2..sheet.last_row).each do |row_idx|
        raw = sheet.row(row_idx)
        next if raw.compact.empty?

        self.row_num += 1
        row_hash = build_row_hash(raw)
        process_row row_hash
        break if progreso.fue_cancelado?

        progreso.avanzar
      rescue ActiveRecord::RecordInvalid => e
        display_error row_idx, e, e.record.errors.full_messages.to_sentence
      rescue ErrorAplicacion, ActiveRecord::RecordNotFound => e
        display_error row_idx, e
      end
      after_process
    end
    save!
  end

  def row_num
    @row_num ||= 1
  end

  private

  def before_process
    # Callback para ejecutar algo al principio de la importación
  end

  def after_process
    # Callback para ejecutar algo al final de la importación
  end

  def open_spreadsheet(file)
    Roo::Spreadsheet.open(file, extension: 'xlsx')
  end

  def display_error(row_number, exception, message = exception)
    logger.error exception.backtrace
    error! "Error en fila #{row_number}: #{message}"
  end

  def build_row_hash(raw)
    hash = {}
    @headers.each_with_index do |header, col|
      next if header.blank?

      value = raw[col]
      value = if value.is_a?(String)
                value.strip
              else
                (value.nil? ? '' : value)
              end
      value = value.to_i if value.is_a?(Float) && value == value.to_i
      hash[header] = value
    end
    hash
  end
end
