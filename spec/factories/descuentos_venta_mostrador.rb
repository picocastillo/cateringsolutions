FactoryBot.define do
  factory :descuento_venta_mostrador, class: 'VentasMostrador::DescuentoVentaMostrador' do
    association :tienda
    nombre { 'Descuento Efectivo' }
    tipo_descuento { 'importe' }
    importe { 500.0 }
    medio_pago_tipo { 'efectivo' }
    importe_minimo { 0.0 }
    activo { true }

    trait :porcentaje do
      tipo_descuento { 'porcentaje' }
      importe { nil }
      porcentaje { 10.0 }
      limite_bonificacion { nil }
    end

    trait :porcentaje_con_limite do
      tipo_descuento { 'porcentaje' }
      importe { nil }
      porcentaje { 15.0 }
      limite_bonificacion { 2000.0 }
    end

    trait :inactivo do
      activo { false }
    end

    trait :qr do
      medio_pago_tipo { 'qr' }
      nombre { 'Descuento QR' }
    end

    trait :debito do
      medio_pago_tipo { 'debito' }
      nombre { 'Descuento Débito' }
    end
  end
end
