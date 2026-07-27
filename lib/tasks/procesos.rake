namespace :procesos do
  desc 'Elimina procesos con más de 1 año de antigüedad junto con sus archivos adjuntos'
  task purgar_antiguos: :environment do
    count = Infraestructura::Procesos::Proceso.where(created_at: ...1.year.ago).count
    puts "Purgando #{count} procesos antiguos..."
    Infraestructura::Procesos::Proceso.purgar_antiguos
    puts 'Listo.'
  end
end
