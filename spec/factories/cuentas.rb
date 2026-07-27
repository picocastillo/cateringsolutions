FactoryBot.define do
  factory :cuenta, class: 'Clientes::Cuenta' do
    nombre { Faker::Name.name }
    association :cliente, factory: :cliente
    position { 1 }
    cuenta_corriente_parcial { nil }

    trait :with_usuario do
      after(:create) do |cuenta|
        create(:usuario, :cliente, cuenta: cuenta, tienda_cliente: cuenta.cliente.tienda)
      end
    end
  end
end
