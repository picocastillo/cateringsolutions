# Script para inicializar datos de turnos de entrega

# Crear los 3 turnos base
ActiveRecord::Base.connection.execute(
  'INSERT INTO turnos_entrega (nombre, codigo, hora_corte, descripcion, activo, posicion, created_at, updated_at) VALUES ' \
  "('Desayuno', 'desayuno', '07:00:00', 'Turno matutino - Solo Kiosco y Bebidas', true, 1, NOW(), NOW()), " \
  "('Almuerzo', 'almuerzo', '11:00:00', 'Turno mediodía - Todas las categorías', true, 2, NOW(), NOW()), " \
  "('Merienda', 'merienda', '15:00:00', 'Turno tarde - Solo Kiosco y Bebidas', true, 3, NOW(), NOW())"
)

# Obtener IDs
desayuno = Pedidos::TurnoEntrega.find_by(codigo: 'desayuno')
almuerzo = Pedidos::TurnoEntrega.find_by(codigo: 'almuerzo')
merienda = Pedidos::TurnoEntrega.find_by(codigo: 'merienda')

Rails.logger.debug { "Turnos creados: #{desayuno.id}, #{almuerzo.id}, #{merienda.id}" }

# Asignar almuerzo a todos los clientes
Clientes::Cliente.active.find_each do |cliente|
  Pedidos::ClienteTurnoEntrega.create!(cliente_id: cliente.id, turno_entrega_id: almuerzo.id)
end

Rails.logger.debug { "Almuerzo asignado a #{Clientes::Cliente.active.count} clientes" }

# Asignar los 3 turnos a clientes con horarios_de_entrega = true
Clientes::Cliente.active.where(horarios_de_entrega: true).find_each do |cliente|
  [desayuno, merienda].each do |turno|
    unless Pedidos::ClienteTurnoEntrega.exists?(cliente_id: cliente.id, turno_entrega_id: turno.id)
      Pedidos::ClienteTurnoEntrega.create!(cliente_id: cliente.id, turno_entrega_id: turno.id)
    end
  end
end

# Asignar los 3 turnos a clientes específicos (IDs 22, 23, 24)
[22, 23, 24].each do |cliente_id|
  cliente = Clientes::Cliente.find_by(id: cliente_id)
  next unless cliente&.active?

  [desayuno, almuerzo, merienda].each do |turno|
    unless Pedidos::ClienteTurnoEntrega.exists?(cliente_id: cliente.id, turno_entrega_id: turno.id)
      Pedidos::ClienteTurnoEntrega.create!(cliente_id: cliente.id, turno_entrega_id: turno.id)
    end
  end
end

Rails.logger.debug 'Turnos especiales asignados'

# Mapear categorías para Catering Solutions (tienda_id = 1)
categorias_kiosco_bebidas = Productos::Categoria.where(tienda_id: 1).active.where('nombre IN (?, ?, ?, ?)', 'Kiosco',
                                                                                  'Bebidas', 'KIOSCO', 'BEBIDAS')

categorias_kiosco_bebidas.each do |cat|
  [desayuno, merienda].each do |turno|
    Pedidos::TurnoEntregaCategoria.create!(turno_entrega_id: turno.id, categoria_id: cat.id)
  end
end

Rails.logger.debug { "Categorías mapeadas: #{categorias_kiosco_bebidas.count} categorías a desayuno y merienda" }
Rails.logger.debug 'Migración de datos completada!'
