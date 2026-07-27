FactoryBot.define do
  factory :stock, class: 'Productos::Stock' do
    transient do
      tienda_for_all { create(:tienda) }
    end

    association :tienda, factory: :tienda, strategy: :build
    association :producto, factory: :producto, strategy: :build
    cantidad_actual { 10.0 }
    cantidad_minima { 5.0 }
    cantidad_maxima { 100.0 }
    activo { true }

    # Ensure tienda consistency between stock and producto
    before(:create) do |stock, evaluator|
      # Use the same tienda for both stock and producto
      stock.tienda = evaluator.tienda_for_all unless stock.tienda.persisted?

      unless stock.producto.persisted?
        stock.producto.tienda = stock.tienda
        stock.producto.categoria.tienda = stock.tienda unless stock.producto.categoria.persisted?
        stock.producto.categoria.save!
        # Save without running after_create callback to prevent duplicate stock creation
        Productos::Producto.skip_callback(:create, :after, :crear_stock_inicial)
        stock.producto.save!
        Productos::Producto.set_callback(:create, :after, :crear_stock_inicial)
      end
    end

    trait :sin_stock do
      cantidad_actual { 0.0 }
    end

    trait :stock_bajo do
      cantidad_actual { 3.0 }
      cantidad_minima { 10.0 }
    end

    trait :stock_critico do
      cantidad_actual { 1.0 }
      cantidad_minima { 5.0 }
    end

    trait :con_local do
      association :local, factory: :local
    end
  end
end
