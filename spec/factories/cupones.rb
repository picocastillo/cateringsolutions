FactoryBot.define do
  factory :cupon, class: 'Cupones::Cupon' do
    association :tienda, factory: :tienda
    tipo_descuento { 'importe' }
    importe { 500 }
    fecha_vencimiento { Date.current + 3.months }

    trait :porcentaje do
      tipo_descuento { 'porcentaje' }
      importe { nil }
      porcentaje { 10 }
      limite_bonificacion { 1000 }
    end

    trait :vencido do
      fecha_vencimiento { Date.current - 1.day }
    end

    trait :cancelado do
      cancelado { true }
    end

    trait :con_grupo do
      grupo { SecureRandom.uuid }
    end
  end
end
