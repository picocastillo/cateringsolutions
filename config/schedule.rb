set :path, '/var/www/kiosk/current'
set :job_template, "/bin/bash -l -c ':job'"
env 'MAILTO', 'sebachavarini@gmail.com'

every '*/5 * * * *' do # Changed from every minute to every 5 minutes
  runner 'Clientes::Cliente.confirmar_pedidos_aceptados'
end

every '0 3 * * *' do
  runner 'Pedidos::Pedido.borrar_pendientes'
end

# Send daily stock alerts at 3 PM
every 1.day, at: '3:00 pm' do
  runner 'Tiendas::Tienda.enviar_alertas_stock'
end

# Update dollar exchange rate: first at 12:01 AM to initialize the day, then again at 3:05 PM
every 1.day, at: '12:01 am' do
  rake 'cotizacion:actualizar_dolar'
end

every 1.day, at: '3:05 pm' do
  rake 'cotizacion:actualizar_dolar'
end

# Collect daily metrics at 3:10 AM (staggered from borrar_pendientes at 3:00)
every 1.day, at: '3:10 am' do
  rake 'metricas:daily'
end

# Send monthly consumption report on the 1st of each month at 11 AM
every '0 11 1 * *' do
  rake 'consumos:reporte_mensual'
end

# Clean up old sessions every Sunday at 4 AM (well after 3 AM jobs finish)
every :sunday, at: '4:00 am' do
  rake 'sessions:cleanup'
end

# Purge procesos older than 1 year on the first Sunday of each month at 4 AM
every '0 4 1-7 * 0' do
  rake 'procesos:purgar_antiguos'
end

# Daily ledger-gap surveillance: prints any pedidos whose afectaciones gap
# exceeds the threshold so they get picked up before customers notice.
every 1.day, at: '6:00 am' do
  rake 'data_fixes:print_gap_summary'
end

# Daily duplicate-row guard: detects any productos_solicitados / renglones
# duplicates that slipped past the unique indexes (would indicate a regression).
every 1.day, at: '6:05 am' do
  rake 'data_fixes:check_duplicates'
end
