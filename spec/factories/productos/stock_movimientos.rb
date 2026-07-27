FactoryBot.define do
  factory :stock_movimiento, class: 'Productos::StockMovimiento' do
    association :stock, factory: :stock
    association :usuario, factory: :usuario
    tipo { 'entrada' }
    cantidad { 10.0 }
    cantidad_anterior { 5.0 }
    cantidad_nueva { 15.0 }
    motivo { 'Reposición de stock' }
    fecha { Time.current }

    trait :entrada do
      tipo { 'entrada' }
    end

    trait :salida do
      tipo { 'salida' }
      cantidad_anterior { 15.0 }
      cantidad_nueva { 10.0 }
    end

    trait :venta do
      tipo { 'venta' }
      motivo { 'Venta realizada' }
      cantidad_anterior { 15.0 }
      cantidad_nueva { 10.0 }
    end

    trait :ajuste do
      tipo { 'ajuste_entrada' }
      motivo { 'Ajuste por inventario' }
    end

    trait :devolucion do
      tipo { 'devolucion' }
      motivo { 'Devolución de cliente' }
    end
  end
end
