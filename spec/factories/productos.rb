FactoryBot.define do
  factory :producto, class: 'Productos::Producto' do
    sequence(:nombre) { |n| "Producto #{n}" }
    sequence(:codigo) { |n| "PROD#{n.to_s.rjust(3, '0')}" }
    descripcion { 'Descripción del producto' }
    association :tienda, factory: :tienda
    association :categoria, factory: :categoria, stock_activo: true

    trait :with_price do
      after(:create) do |producto|
        create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current)
      end
    end

    trait :with_client_prices do
      transient do
        cliente { nil }
        client_price { 150.0 }
        general_price { 100.0 }
      end

      after(:create) do |producto, evaluator|
        # Create a general price (no specific client)
        create(:precio,
               producto: producto,
               importe: evaluator.general_price,
               fecha_desde: Date.current)

        # Create a client-specific price
        if evaluator.cliente
          client_precio = create(:precio,
                                 producto: producto,
                                 importe: evaluator.client_price,
                                 fecha_desde: Date.current)
          client_precio.clientes << evaluator.cliente
        end
      end
    end
  end
end
