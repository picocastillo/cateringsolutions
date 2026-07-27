module Pedidos
  class PedidosImporter < ExcelImporter
    # This Excel has a non-standard layout:
    #   Row 1: date marker (e.g., "2026-04-13")
    #   Row 2: column headers
    #   Row 3+: data rows
    #
    # The base ExcelImporter assumes row 1 = headers, so we override `run`.

    def extra_broadcast_data
      { pedidos_count: @pedidos&.size || 0 }
    end

    def run(file)
      @pedidos = []
      @pedidos_by_employee = {}

      spreadsheet = open_spreadsheet(file)
      sheet = spreadsheet.sheet(0)
      total_rows = sheet.last_row ? sheet.last_row - 2 : 0 # Subtract date row + header row

      progreso.track total_rows do
        load_params!
        validate_date_marker!(sheet)
        load_headers!(sheet)
        validate_no_duplicates_upfront!

        (3..sheet.last_row).each do |row_idx|
          raw = sheet.row(row_idx)
          next if raw.compact.empty?

          self.row_num += 1
          process_data_row(raw, row_idx)
          break if progreso.fue_cancelado?

          progreso.avanzar
        rescue ErrorAplicacion, ActiveRecord::RecordNotFound => e
          display_error row_idx, e
        end

        save_and_confirm_pedidos!
      end
      save!
    end

    private

    def load_params!
      @cliente = Clientes::Cliente.find(params['cliente_id'].to_i)
      @fecha = params['fecha'].to_date
      @tienda = autor.tienda_activa
    end

    def validate_date_marker!(sheet)
      first_row = sheet.row(1)
      return if first_row[0].to_s.include?(@fecha.to_fs(:db))

      raise ErrorAplicacion,
            "Está intentando cargar un archivo que no coincide con la fecha solicitada: #{@fecha}. Ver Fila 1."
    end

    def load_headers!(sheet)
      @col_headers = {}
      sheet.row(2).each_with_index do |cell, idx|
        @col_headers[cell.to_s.strip] = idx if cell.present?
      end
    end

    def validate_no_duplicates_upfront!
      # Pre-check all cuentas for existing pedidos (fail fast before processing rows)
    end

    def process_data_row(raw, row_idx)
      cuenta = find_cuenta(raw, row_idx)
      check_duplicate_pedidos!(cuenta, row_idx)

      nombre_empleado = normalize_employee_name(raw[@col_headers['Nombre de empleado']])
      ped = find_or_build_pedido(nombre_empleado, cuenta)

      cod = raw[@col_headers['Código del menú']]
      producto = find_producto(cod, raw, row_idx)
      menu_diario = find_menu_diario(producto, ped)

      existing_ps = ped.productos_solicitados.find { |x| x.producto == producto } if @pedidos_by_employee.key?(nombre_empleado)

      if existing_ps
        existing_ps.cantidad = existing_ps.cantidad.to_i + 1
      else
        precio = find_precio(producto, ped, row_idx)
        cant = parse_cantidad(raw)
        ped.productos_solicitados.build producto: producto, cantidad: cant, precio_unitario: precio, menu_diario: menu_diario
      end

      return if @pedidos_by_employee.key?(nombre_empleado)

      @pedidos_by_employee[nombre_empleado] = ped
      @pedidos << ped
    end

    def find_cuenta(raw, row_idx)
      lugar = raw[@col_headers['Lugar de entrega']].to_s.strip
      cuenta = @cliente.cuentas.find { |x| x.nombre == lugar }
      return cuenta if cuenta

      raise ErrorAplicacion,
            'No se permiten pedidos con cuentas Inválidas. ' \
            "No existe la cuenta #{lugar} " \
            "para el cliente #{@cliente}. Ver Fila #{row_idx}."
    end

    def check_duplicate_pedidos!(cuenta, row_idx)
      return unless Pedidos::Pedido.where(fecha: @fecha, cuenta_id: cuenta.id, usuario_id: nil)
                                   .where.not(estado_id: 5).exists?

      raise ErrorAplicacion,
            "Ya se registran pedidos cargados para este día para la cuenta #{cuenta}. Ver Fila #{row_idx}. " \
            'Cancele todos los pedidos de esta cuenta para poder cargarlos nuevamente.'
    end

    def normalize_employee_name(raw_name)
      raw_name.to_s.gsub(',', '').split.map(&:capitalize).join(' ')
    end

    def find_or_build_pedido(nombre_empleado, cuenta)
      @pedidos_by_employee[nombre_empleado] || Pedidos::Pedido.new(
        cuenta: cuenta, estado_id: 2, para: nombre_empleado, fecha: @fecha,
        pedido_para_empresa: true, autor: autor, tienda: @tienda
      )
    end

    def find_producto(cod, raw, row_idx)
      producto = Productos::Producto.active
                                    .where('productos.codigos_externos rlike ?',
                                           "(^|,\\s?)#{Regexp.quote cod.to_s}($|,\\s?)")
                                    .where(tienda_id: @tienda.id).first
      producto ||= Productos::Producto.active.find_by(codigo: cod, tienda_id: @tienda.id)
      return producto if producto

      nombre_menu = raw[@col_headers['Nombre del menú']]
      raise ErrorAplicacion,
            "No existe ningún producto activo con el código (#{cod}) en el sistema. " \
            "Intente localizar el producto con nombre similar a '#{nombre_menu}' " \
            "y verifique que tenga asignado dicho código. Ver Fila #{row_idx}."
    end

    def find_menu_diario(producto, pedido)
      return unless producto.categoria.menu_diario

      producto.menus_diarios.where(fecha: pedido.fecha, tipo_id: ::MenusDiarios::Tipo[:menu_diario].id).first
    end

    def find_precio(producto, pedido, row_idx)
      precio = producto.buscar_precio(pedido.cuenta.cliente, pedido.fecha).try(&:importe)
      return precio if precio

      raise ErrorAplicacion,
            "No existen precios activos del producto '#{producto.codigo} - #{producto.nombre}' " \
            "para el cliente '#{@cliente}' en el sistema. " \
            "Cargue un precio e intente nuevamente. Ver Fila #{row_idx}."
    end

    def parse_cantidad(raw)
      col = @col_headers['Cantidad']
      return 1 unless col && raw[col]&.to_i&.positive?

      raw[col].to_i
    end

    def save_and_confirm_pedidos!
      return if @pedidos.empty?

      if progreso.error?
        progreso.add_error 'Importación cancelada por errores. No se crearon pedidos.'
        return
      end

      ActiveRecord::Base.transaction do
        @pedidos.each do |ped|
          ped.save!
          ped.confirmar!(autor)
        end
      end
    rescue StandardError => e
      progreso.add_error "Error al confirmar pedidos: #{e.message}"
      raise
    end
  end
end
