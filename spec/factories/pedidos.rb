FactoryBot.define do
  factory :pedido, class: 'Pedidos::Pedido' do
    fecha { Date.current }
    association :tienda
    association :autor, factory: :usuario
    association :usuario, factory: :usuario # Add usuario association
    association :cuenta
    estado_id { 1 } # pendiente

    trait :with_productos do
      after(:build) do |pedido|
        pedido.productos_solicitados.build(attributes_for(:producto_solicitado).except(:pedido))
      end

      after(:create) do |pedido|
        # Ensure the producto_solicitado is properly set up with producto and precio
        ps = pedido.productos_solicitados.first
        if ps && !ps.producto
          categoria = create(:categoria, tienda: pedido.tienda, nombre: 'Categoría Test')
          ps.producto = create(:producto, tienda: pedido.tienda, categoria: categoria)
          precio = create(:precio, producto: ps.producto, importe: 150)
          ps.precio_unitario = precio.importe
          ps.save!
        end
      end
    end

    trait :confirmado do
      estado_id { 3 } # confirmado - ready for cocina
      pedido_cocina_id { nil } # not assigned to any pedido_cocina yet
    end

    trait :aceptado do
      estado_id { 2 } # aceptado
    end

    trait :cancelado do
      estado_id { 5 } # cancelado
    end

    trait :with_multiple_productos do
      after(:build) do |pedido|
        3.times { pedido.productos_solicitados.build(attributes_for(:producto_solicitado).except(:pedido)) }
      end

      after(:create) do |pedido|
        # Ensure all productos_solicitados are properly set up
        categoria = create(:categoria, tienda: pedido.tienda, nombre: 'Categoría Test')
        pedido.productos_solicitados.each do |ps|
          next if ps.producto

          ps.producto = create(:producto, tienda: pedido.tienda, categoria: categoria)
          precio = create(:precio, producto: ps.producto, importe: rand(100..500))
          ps.precio_unitario = precio.importe
          ps.save!
        end
      end
    end
  end
end
