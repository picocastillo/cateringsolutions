FactoryBot.define do
  factory :comprobante_tipo, class: 'Comprobantes::Tipo' do
    trait :factura do
      desc { 'Factura' }
      clase { 'Ventas::Facturacion::Factura' }
      letra { 'A' }
      codigo { 1 }
      debitan { false }
    end

    trait :nota_debito do
      desc { 'Nota de Débito' }
      clase { 'Ventas::Facturacion::NotaDebito' }
      letra { 'A' }
      codigo { 2 }
      debitan { true }
    end

    trait :nota_credito do
      desc { 'Nota de Crédito' }
      clase { 'Ventas::Facturacion::NotaCredito' }
      letra { 'A' }
      codigo { 3 }
      debitan { false }
    end

    trait :recibo do
      desc { 'Recibo' }
      clase { 'Cobros::Recibo' }
      letra { 'A' }
      codigo { 4 }
      debitan { false }
    end

    trait :orden_pago do
      desc { 'Orden de Pago' }
      clase { 'Ventas::Facturacion::OrdenPago' }
      letra { 'A' }
      codigo { 5 }
      debitan { false }
    end

    trait :pago do
      desc { 'Pago' }
      clase { 'Entregas::Pago' }
      letra { 'A' }
      codigo { 6 }
      debitan { false }
    end
  end
end
