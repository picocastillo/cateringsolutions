FactoryBot.define do
  factory :categoria, class: 'Productos::Categoria' do
    sequence(:nombre) { |n| "Categoría #{n}" }
    association :tienda, factory: :tienda

    trait :stock_activo do
      stock_activo { true }
    end

    trait :vender_en_carrito do
      vender_en_carrito { true }
    end
  end
end
