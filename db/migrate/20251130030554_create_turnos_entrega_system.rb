class CreateTurnosEntregaSystem < ActiveRecord::Migration[5.2]
  def up
    # Tabla principal de turnos
    create_table :turnos_entrega do |t|
      t.string :nombre, null: false
      t.string :codigo, null: false
      t.time :hora_corte, null: false
      t.text :descripcion
      t.boolean :activo, default: true, null: false
      t.integer :posicion, default: 0, null: false
      t.timestamps
    end

    add_index :turnos_entrega, :codigo, unique: true
    add_index :turnos_entrega, :activo

    # Tabla de relación clientes -> turnos (many-to-many)
    create_table :clientes_turnos_entrega do |t|
      t.bigint :cliente_id, null: false
      t.bigint :turno_entrega_id, null: false
      t.timestamps
    end

    add_foreign_key :clientes_turnos_entrega, :clientes, column: :cliente_id
    add_foreign_key :clientes_turnos_entrega, :turnos_entrega, column: :turno_entrega_id
    add_index :clientes_turnos_entrega, :cliente_id
    add_index :clientes_turnos_entrega, :turno_entrega_id

    add_index :clientes_turnos_entrega, [:cliente_id, :turno_entrega_id], 
              unique: true, 
              name: 'index_clientes_turnos_on_cliente_and_turno'

    # Tabla de relación turnos -> categorías (many-to-many)
    create_table :turnos_entrega_categorias do |t|
      t.bigint :turno_entrega_id, null: false
      t.bigint :categoria_id, null: false
      t.timestamps
    end

    add_foreign_key :turnos_entrega_categorias, :turnos_entrega, column: :turno_entrega_id
    add_foreign_key :turnos_entrega_categorias, :categorias, column: :categoria_id
    add_index :turnos_entrega_categorias, :turno_entrega_id
    add_index :turnos_entrega_categorias, :categoria_id
    add_index :turnos_entrega_categorias, [:turno_entrega_id, :categoria_id],
              unique: true,
              name: 'index_turnos_categorias_on_turno_and_categoria'

    # Agregar columna a pedidos (si no existe ya)
    unless column_exists?(:pedidos, :turno_entrega_id)
      add_column :pedidos, :turno_entrega_id, :bigint
      add_index :pedidos, :turno_entrega_id
      add_foreign_key :pedidos, :turnos_entrega, column: :turno_entrega_id
    end

    # Crear los 3 turnos base
    execute <<-SQL
      INSERT INTO turnos_entrega (nombre, codigo, hora_corte, descripcion, activo, posicion, created_at, updated_at)
      VALUES
        ('Desayuno', 'desayuno', '07:00:00', 'Turno matutino - Solo Kiosco y Bebidas', true, 1, NOW(), NOW()),
        ('Almuerzo', 'almuerzo', '11:00:00', 'Turno mediodía - Todas las categorías', true, 2, NOW(), NOW()),
        ('Merienda', 'merienda', '15:00:00', 'Turno tarde - Solo Kiosco y Bebidas', true, 3, NOW(), NOW())
    SQL

    # Obtener IDs de los turnos recién creados usando ActiveRecord
    desayuno_id = Pedidos::TurnoEntrega.find_by(codigo: 'desayuno').id
    almuerzo_id = Pedidos::TurnoEntrega.find_by(codigo: 'almuerzo').id
    merienda_id = Pedidos::TurnoEntrega.find_by(codigo: 'merienda').id

    # Asignar turno "almuerzo" a TODOS los clientes
    execute <<-SQL
      INSERT INTO clientes_turnos_entrega (cliente_id, turno_entrega_id, created_at, updated_at)
      SELECT id, #{almuerzo_id}, NOW(), NOW()
      FROM clientes
      WHERE discontinued_at IS NULL
    SQL

    # Asignar los 3 turnos a clientes con horarios_de_entrega = true
    execute <<-SQL
      INSERT INTO clientes_turnos_entrega (cliente_id, turno_entrega_id, created_at, updated_at)
      SELECT c.id, t.id, NOW(), NOW()
      FROM clientes c
      CROSS JOIN turnos_entrega t
      WHERE c.horarios_de_entrega = true
        AND c.discontinued_at IS NULL
        AND t.codigo IN ('desayuno', 'merienda')
        AND NOT EXISTS (
          SELECT 1 FROM clientes_turnos_entrega cte
          WHERE cte.cliente_id = c.id AND cte.turno_entrega_id = t.id
        )
    SQL

    # Asignar los 3 turnos a clientes específicos (IDs 22, 23, 24)
    # VMG S.A., EQUIPO ORIGINAL VMG, CHIAPERO ASOCIADOS
    execute <<-SQL
      INSERT INTO clientes_turnos_entrega (cliente_id, turno_entrega_id, created_at, updated_at)
      SELECT c.id, t.id, NOW(), NOW()
      FROM clientes c
      CROSS JOIN turnos_entrega t
      WHERE c.id IN (22, 23, 24)
        AND c.discontinued_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM clientes_turnos_entrega cte
          WHERE cte.cliente_id = c.id AND cte.turno_entrega_id = t.id
        )
    SQL

    # Mapear categorías para Catering Solutions (tienda_id = 1)
    # Solo aplicar si la tienda existe (para producción/desarrollo, no tests vacíos)
    if ActiveRecord::Base.connection.table_exists?('productos_categorias')
      # Obtener IDs de categorías "Kiosco" y "Bebidas"
      kiosco_bebidas_ids = execute(<<-SQL
        SELECT id FROM productos_categorias
        WHERE tienda_id = 1
          AND discontinued_at IS NULL
          AND nombre IN ('Kiosco', 'Bebidas', 'KIOSCO', 'BEBIDAS')
      SQL
      ).map { |row| row.is_a?(Hash) ? row['id'] : row[0] }

      # Asignar categorías Kiosco y Bebidas a turnos desayuno y merienda
      if kiosco_bebidas_ids.any?
        kiosco_bebidas_ids.each do |cat_id|
          execute <<-SQL
            INSERT INTO turnos_entrega_categorias (turno_entrega_id, categoria_id, created_at, updated_at)
            VALUES
              (#{desayuno_id}, #{cat_id}, NOW(), NOW()),
              (#{merienda_id}, #{cat_id}, NOW(), NOW())
          SQL
        end
      end
    end

    # El turno "almuerzo" NO tiene restricciones (permite todas las categorías)
    # Por lo tanto, NO insertamos registros en turnos_entrega_categorias para almuerzo
  end

  def down
    remove_foreign_key :pedidos, :turnos_entrega
    remove_column :pedidos, :turno_entrega_id
    drop_table :turnos_entrega_categorias
    drop_table :clientes_turnos_entrega
    drop_table :turnos_entrega
  end
end
