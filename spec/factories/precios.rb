FactoryBot.define do
  factory :precio, class: 'Productos::Precio' do
    importe { 100.0 }
    fecha_desde { Date.current }
    fecha_hasta { Date.current + 1.year }
    association :producto

    trait :for_cliente do
      transient do
        cliente { nil }
      end

      after(:create) do |precio, evaluator|
        precio.clientes << evaluator.cliente if evaluator.cliente && precio.clientes.exclude?(evaluator.cliente)
      end
    end

    trait :with_specific_client do
      transient do
        cliente { nil }
      end

      after(:create) do |precio, evaluator|
        precio.clientes << evaluator.cliente if evaluator.cliente
      end
    end
  end
end
