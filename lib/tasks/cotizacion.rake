namespace :cotizacion do
  desc 'Actualiza el precio del dólar oficial para hoy en la tabla cotizaciones_dolar'
  task actualizar_dolar: :environment do
    registro = Cotizaciones::Dolar.actualizar!
    if registro
      Rails.logger.info "Cotización del dólar actualizada: $#{registro.precio_venta} para #{registro.fecha}"
      puts "Cotización del dólar actualizada: $#{registro.precio_venta} para #{registro.fecha}"
    else
      Rails.logger.error 'Error al obtener cotización del dólar'
      abort 'Error al obtener cotización del dólar'
    end
  end

  desc 'Backfill cotizaciones históricas desde una fecha (default: primer comprobante)'
  task :backfill, [:from_date] => :environment do |_t, args|
    from_date = if args[:from_date].present?
                  Date.parse(args[:from_date])
                else
                  Comprobantes::Comprobante.minimum(:fecha_emision)&.to_date
                end

    unless from_date
      puts 'No hay comprobantes en el sistema, nada que backfillear.'
      next
    end

    puts "Backfilling cotizaciones desde #{from_date} hasta #{Date.current}..."
    count = Cotizaciones::Dolar.backfill!(from_date: from_date)
    puts "Backfill completado: #{count} cotizaciones agregadas."
  end
end
