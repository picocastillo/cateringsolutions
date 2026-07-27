module Ventas
  module Facturacion
    class VentasPorCategoriaExporter < ExcelExporter
      MONTH_ABBRS = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'].freeze
      TABLA_SHEET_NAME = 'Ventas por Categoría'.freeze
      MAX_MONTHS = 120

      # Override run entirely — this is a pivot table, not a row-per-record export.
      def run(_objects)
        preparar_adjunto filename

        @workbook = WriteXLSX.new(xlsx_filepath, optimization: false)
        setup_formats

        meses, pivot, categorias = compute_data

        tabla_sheet = @workbook.add_worksheet(TABLA_SHEET_NAME)
        write_tabla(tabla_sheet, meses, pivot, categorias)

        build_chart(meses, categorias) if categorias.any? && meses.any?

        @workbook.close
        make_zip if zippear?
      end

      # Used by Exporter#export_started to count rows for progress tracking.
      def search_scope
        ComprobantesQuery.new(query_params.merge(estado_id: 2)).relation
      end

      private

      # ─── Data ──────────────────────────────────────────────────────────────────

      def compute_data
        user      = query_params[:user]
        tienda    = user.tienda_activa
        tienda_id = tienda.id
        local_id  = tienda.multiple_locales? && user.local_activo ? user.local_activo.id : nil

        desde     = parse_date(query_params[:emitidos_desde]) || Time.zone.today.beginning_of_month.to_date
        hasta     = parse_date(query_params[:emitidos_hasta]) || Time.zone.today.to_date

        desde, hasta = hasta, desde if desde > hasta

        meses = generate_months(desde, hasta).first(MAX_MONTHS)

        sql_importe = <<~SQL.squish
          CASE WHEN renglones.peso IS NOT NULL AND renglones.peso > 0
            THEN renglones.precio_unitario * renglones.cantidad * renglones.peso
            ELSE renglones.precio_unitario * renglones.cantidad
          END
        SQL
        sql_signed = "IF(tipos_comprobantes.debitan = 1, (#{sql_importe}), -(#{sql_importe}))"

        rows = Ventas::Facturacion::Renglon
               .joins(comprobante: :tipo)
               .joins('LEFT JOIN categorias ON categorias.id = renglones.categoria_id')
               .where(comprobantes: { tienda_id: tienda_id, estado_id: 2 })
               .then { |q| local_id ? q.where(comprobantes: { local_id: local_id }) : q }
               .where(comprobantes: { type: ['Ventas::Facturacion::Factura', 'Ventas::Facturacion::NotaCredito'] })
               .where(comprobantes: { fecha_emision: desde.beginning_of_day.. })
               .where(comprobantes: { fecha_emision: ..hasta.end_of_day })
               .group(
                 "COALESCE(categorias.nombre, 'Sin Categoría')",
                 "DATE_FORMAT(comprobantes.fecha_emision, '%Y-%m')"
               )
               .select(
                 "COALESCE(categorias.nombre, 'Sin Categoría') AS categoria_nombre",
                 "DATE_FORMAT(comprobantes.fecha_emision, '%Y-%m') AS mes",
                 "SUM(#{sql_signed}) AS importe_total"
               )

        pivot = Hash.new { |h, k| h[k] = Hash.new(0.0) }
        rows.each { |r| pivot[r.categoria_nombre][r.mes] = r.importe_total.to_f }

        categorias = pivot.keys.sort

        [meses, pivot, categorias]
      end

      def generate_months(desde, hasta)
        months  = []
        current = desde.beginning_of_month
        until current > hasta
          months << current.strftime('%Y-%m')
          current = current.next_month
        end
        months
      end

      def parse_date(value)
        return nil if value.blank?
        return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)

        Date.strptime(value.to_s.strip, '%d/%m/%Y')
      rescue ArgumentError, TypeError
        nil
      end

      def format_mes(mes)
        year, month = mes.split('-')
        "#{MONTH_ABBRS[month.to_i - 1]}-#{year}"
      end

      # ─── Sheet 1: Pivot table ──────────────────────────────────────────────────

      def write_tabla(sheet, meses, pivot, categorias)
        @current_row = 0
        last_col     = 1 + meses.size

        sheet.set_column(0, 0, 32)
        sheet.set_column(1, last_col, 16)

        # Header row
        sheet.write(@current_row, 0, 'Categoría', @header_format)
        sheet.write(@current_row, 1, 'TOTALES',   @header_format)
        meses.each_with_index { |m, i| sheet.write(@current_row, 2 + i, format_mes(m), @header_format) }
        @current_row += 1

        # One row per categoria (alphabetical)
        categorias.each do |cat|
          mes_values = meses.map { |m| pivot[cat][m] }
          sheet.write(@current_row, 0, cat)
          sheet.write(@current_row, 1, mes_values.sum, @currency_format)
          mes_values.each_with_index { |v, i| sheet.write(@current_row, 2 + i, v, @currency_format) }
          @current_row += 1
        end

        # TODAS: sum of all categorias per month
        mes_totals  = meses.map { |m| categorias.sum { |c| pivot[c][m] } }
        todas_total = mes_totals.sum
        sheet.write(@current_row, 0, 'TODAS', @total_currency)
        sheet.write(@current_row, 1, todas_total, @total_currency)
        mes_totals.each_with_index { |v, i| sheet.write(@current_row, 2 + i, v, @total_currency) }
        @current_row += 1
      end

      # ─── Sheet 2: Stacked column chart ────────────────────────────────────────
      #
      # Correct array format for series ranges: [sheetname, row_1, row_2, col_1, col_2]
      # (maps to xl_range_formula signature). row_1 == row_2 → 1D horizontal range,
      # which is what get_chart_range requires to populate formula_data from the worksheet.
      #
      def build_chart(meses, categorias)
        last_col   = 1 + meses.size
        chartsheet = @workbook.add_chart(type: 'column', subtype: 'stacked')

        categorias.each_with_index do |cat, i|
          row_index = i + 1 # row 0 is the header row

          chartsheet.add_series(
            name: cat, # plain string — avoid xl_rowcol_to_cell bug
            categories: [TABLA_SHEET_NAME, 0, 0, 2, last_col], # row_1==row_2 → 1D horizontal range ✓
            values: [TABLA_SHEET_NAME, row_index, row_index, 2, last_col]
          )
        end

        chartsheet.set_title(name: 'Ventas por Categoría y Mes')
        chartsheet.set_x_axis(name: 'Mes')
        chartsheet.set_y_axis(name: 'Importe ($)')
        chartsheet.set_style(10)
      end

      # ─── Helpers ───────────────────────────────────────────────────────────────

      def filename_prefix
        'ventas_por_categoria'
      end
    end
  end
end
