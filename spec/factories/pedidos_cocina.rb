FactoryBot.define do
  factory :pedido_cocina, class: 'Pedidos::PedidoCocina' do
    association :tienda
    association :autor, factory: :usuario
    fecha { Date.current }

    after(:build) do |pedido_cocina|
      pedido_cocina.pedidos = []
    end

    trait :with_pedidos do
      after(:create) do |pedido_cocina|
        # Create cliente and cuenta for pedidos
        cliente = create(:cliente, tienda: pedido_cocina.tienda)
        cuenta = create(:cuenta, cliente: cliente)

        # Create 2 pedidos ready for cocina with all required associations
        pedidos = create_list(:pedido, 2, :confirmado, :with_productos,
                              tienda: pedido_cocina.tienda,
                              usuario: pedido_cocina.autor,
                              autor: pedido_cocina.autor,
                              cuenta: cuenta)
        pedido_cocina.pedidos = pedidos
        pedido_cocina.save!
      end
    end
  end
end
