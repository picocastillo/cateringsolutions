FactoryBot.define do
  factory :turno_entrega, class: 'Pedidos::TurnoEntrega' do
    sequence(:nombre) { |n| "Turno #{n}" }
    sequence(:codigo) { |n| "turno_#{n}" }
    hora_corte { '11:00:00' }
    descripcion { 'Turno de ejemplo' }
    activo { true }
    sequence(:posicion) { |n| n }

    trait :desayuno do
      nombre { 'Desayuno' }
      codigo { 'desayuno' }
      hora_corte { '07:00:00' }
      descripcion { 'Turno matutino - Solo Kiosco y Bebidas' }
      posicion { 1 }
    end

    trait :almuerzo do
      nombre { 'Almuerzo' }
      codigo { 'almuerzo' }
      hora_corte { '11:00:00' }
      descripcion { 'Turno mediodía - Todas las categorías' }
      posicion { 2 }
    end

    trait :merienda do
      nombre { 'Merienda' }
      codigo { 'merienda' }
      hora_corte { '15:00:00' }
      descripcion { 'Turno tarde - Solo Kiosco y Bebidas' }
      posicion { 3 }
    end

    trait :inactivo do
      activo { false }
    end
  end

  factory :cliente_turno_entrega, class: 'Pedidos::ClienteTurnoEntrega' do
    association :cliente, factory: :cliente
    association :turno_entrega, factory: :turno_entrega
  end

  factory :turno_entrega_categoria, class: 'Pedidos::TurnoEntregaCategoria' do
    association :turno_entrega, factory: :turno_entrega
    association :categoria, factory: :categoria
  end
end
