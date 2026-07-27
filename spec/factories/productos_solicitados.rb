FactoryBot.define do
  factory :producto_solicitado, class: 'Productos::ProductoSolicitado' do
    cantidad { rand(1..5) }
    association :pedido

    # Ensure producto has categoria and proper associations
    after(:build) do |producto_solicitado|
      if producto_solicitado.pedido && !producto_solicitado.producto
        # Create categoria if none exists for this tienda
        categoria = Productos::Categoria.find_or_create_by(
          tienda: producto_solicitado.pedido.tienda,
          nombre: 'Categoría General'
        )

        # Create producto with categoria
        producto_solicitado.producto = create(:producto,
                                              tienda: producto_solicitado.pedido.tienda,
                                              categoria: categoria)
      end

      if producto_solicitado.pedido && producto_solicitado.producto
        # Find or create a precio for this product and tienda
        precio = Productos::Precio.find_or_create_by(
          producto: producto_solicitado.producto
        ) do |p|
          p.importe = rand(100..1000)
          p.fecha_desde = 1.month.ago
          p.fecha_hasta = 1.month.from_now
        end
        producto_solicitado.precio_unitario = precio.importe
      end
    end
  end
end
