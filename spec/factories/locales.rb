FactoryBot.define do
  factory :local, class: 'Locales::Local' do
    sequence(:nombre) { |n| "Local #{n}" }
    domicilio { "Dirección #{nombre}" }
    telefono { '123-456-789' }
    association :tienda, factory: :tienda
  end
end
