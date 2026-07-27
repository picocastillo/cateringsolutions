require 'rails_helper'

RSpec.describe Pedidos::PedidosQuery, type: :query do
  let(:tienda) { create(:tienda, carrito_de_compras: true) }
  let(:cliente) { create(:cliente, tienda: tienda) }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:admin_user) do
    user = create(:usuario, :admin, visualizando_tienda: tienda)
    user.tiendas << tienda unless user.tiendas.include?(tienda)
    user
  end

  let(:cliente_user) do
    create(:usuario, :cliente, cuenta: cuenta, visualizando_tienda: tienda, tienda_cliente: tienda)
  end

  let(:categoria) { create(:categoria, tienda: tienda) }
  let(:producto) { create(:producto, tienda: tienda, categoria: categoria) }

  # Helper to create pedido with productos_solicitados
  # Creates as pendiente (estado_id=1) to avoid validations, adds PS, then transitions estado
  def create_pedido_with_ps(attrs = {})
    target_estado = attrs.delete(:estado_id) || 1
    target_tienda = attrs[:tienda] || tienda
    target_cuenta = attrs[:cuenta] || cuenta
    target_autor = attrs[:autor] || admin_user

    pedido = Pedidos::Pedido.new(
      tienda: target_tienda, cuenta: target_cuenta, fecha: attrs[:fecha] || Date.current,
      estado_id: 1, autor: target_autor, usuario: attrs[:usuario] || target_autor
    )
    pedido.save(validate: false)

    prod = create(:producto, tienda: target_tienda, categoria: create(:categoria, tienda: target_tienda))
    ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: prod, cantidad: 5, precio_unitario: 150.0)
    ps.save(validate: false)

    pedido.update_column(:estado_id, target_estado) if target_estado != 1
    pedido.reload
  end

  describe '#base_query' do
    it 'scopes to user tienda_activa' do
      other_tienda = create(:tienda)
      other_cliente = create(:cliente, tienda: other_tienda)
      other_cuenta = create(:cuenta, cliente: other_cliente)

      pedido_in_tienda = create_pedido_with_ps(estado_id: 2)
      pedido_other = create_pedido_with_ps(tienda: other_tienda, cuenta: other_cuenta, estado_id: 2,
                                           autor: create(:usuario, :admin, visualizando_tienda: other_tienda))

      query = described_class.new(user: admin_user)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(pedido_in_tienda.id)
      expect(results.map(&:id)).not_to include(pedido_other.id)
    end

    it 'filters by estado_id for admin users' do
      pedido_aceptado = create_pedido_with_ps(estado_id: 2)
      pedido_confirmado = create_pedido_with_ps(estado_id: 3)

      query = described_class.new(user: admin_user, estado_id: 2)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(pedido_aceptado.id)
      expect(results.map(&:id)).not_to include(pedido_confirmado.id)
    end

    it 'filters by fecha_desde' do
      pedido_old = create_pedido_with_ps(fecha: 1.week.ago, estado_id: 2)
      pedido_today = create_pedido_with_ps(fecha: Date.current, estado_id: 2)

      query = described_class.new(user: admin_user, fecha_desde: Date.current)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(pedido_today.id)
      expect(results.map(&:id)).not_to include(pedido_old.id)
    end

    it 'filters by fecha_hasta' do
      pedido_future = create_pedido_with_ps(fecha: 1.week.from_now, estado_id: 2)
      pedido_today = create_pedido_with_ps(fecha: Date.current, estado_id: 2)

      query = described_class.new(user: admin_user, fecha_hasta: Date.current)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(pedido_today.id)
      expect(results.map(&:id)).not_to include(pedido_future.id)
    end

    it 'excludes pendientes when no_pendientes is true' do
      pedido_pendiente = create_pedido_with_ps(estado_id: 1)
      pedido_aceptado = create_pedido_with_ps(estado_id: 2)

      query = described_class.new(user: admin_user, no_pendientes: true)
      results = query.base_query.to_a

      expect(results.map(&:id)).not_to include(pedido_pendiente.id)
      expect(results.map(&:id)).to include(pedido_aceptado.id)
    end

    it 'filters by cliente_ids for admin users' do
      other_cliente = create(:cliente, tienda: tienda)
      other_cuenta = create(:cuenta, cliente: other_cliente)

      pedido_this_client = create_pedido_with_ps(estado_id: 2)
      pedido_other_client = create_pedido_with_ps(estado_id: 2, cuenta: other_cuenta)

      query = described_class.new(user: admin_user, cliente_ids: cliente.id.to_s)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(pedido_this_client.id)
      expect(results.map(&:id)).not_to include(pedido_other_client.id)
    end

    it 'filters by codigo' do
      pedido = create_pedido_with_ps(estado_id: 2)
      query = described_class.new(user: admin_user, codigo: pedido.codigo)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(pedido.id)
    end
  end

  describe '#relation' do
    it 'includes expected associations' do
      pedido = create_pedido_with_ps(estado_id: 2)

      query = described_class.new(user: admin_user)
      results = query.relation.to_a
      loaded_pedido = results.find { |p| p.id == pedido.id }

      expect(loaded_pedido).to be_present
      # Verify associations are loaded (no N+1)
      expect(loaded_pedido.association(:productos_solicitados)).to be_loaded
      expect(loaded_pedido.association(:autor)).to be_loaded
    end

    it 'orders by fecha desc, codigo desc' do
      pedido1 = create_pedido_with_ps(fecha: Date.current, estado_id: 2)
      pedido2 = create_pedido_with_ps(fecha: 1.day.from_now, estado_id: 2)

      query = described_class.new(user: admin_user, fecha_desde: Date.current)
      results = query.relation.to_a

      idx1 = results.index { |p| p.id == pedido1.id }
      idx2 = results.index { |p| p.id == pedido2.id }

      expect(idx2).to be < idx1 if idx1 && idx2
    end
  end

  describe '#productos' do
    it 'returns products from producto_ids' do
      prod1 = create(:producto, tienda: tienda, categoria: categoria)
      prod2 = create(:producto, tienda: tienda, categoria: categoria)

      query = described_class.new(user: admin_user, producto_ids: "#{prod1.id},#{prod2.id}")
      expect(query.productos.map(&:id)).to contain_exactly(prod1.id, prod2.id)
    end

    it 'returns empty when producto_ids is blank' do
      query = described_class.new(user: admin_user)
      expect(query.productos).to eq([])
    end
  end

  describe 'footer aggregate compatibility' do
    # These tests verify the footer calculations used in _resultados.html.erb
    # so we can safely optimize them later

    before do
      @pedido1 = create_pedido_with_ps(estado_id: 2) # cantidad=5, precio=150
      @pedido2 = create_pedido_with_ps(estado_id: 3) # cantidad=5, precio=150
      @pedido_cancelled = create_pedido_with_ps(estado_id: 5) # cancelled
    end

    let(:query) { described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current) }

    it 'counts distinct pedidos correctly' do
      count = query.base_query.group('pedidos.id').count.count
      # Should count non-pendiente pedidos that have PS (inner join)
      expect(count).to be >= 2 # at least the 2 non-cancelled (estado 2 and 3)
    end

    it 'sums productos_solicitados cantidad' do
      total_qty = query.base_query.joins(:productos_solicitados).sum('productos_solicitados.cantidad')
      expect(total_qty).to be >= 10 # at least 5+5 from the two non-cancelled pedidos
    end

    it 'sums total excluding cancelled pedidos' do
      total = query.base_query.joins(:productos_solicitados).where.not(estado_id: 5)
                   .sum('(COALESCE(productos_solicitados.precio_con_descuento, productos_solicitados.precio_unitario) * productos_solicitados.cantidad * COALESCE(productos_solicitados.peso, 1)) + pedidos.costo_envio_domicilio')
      expect(total).to be >= 1500.0 # at least 5*150 + 5*150
    end
  end

  describe 'venta_mostrador filter' do
    it 'returns only non-VM pedidos when venta_mostrador is false' do
      pedido_normal = create_pedido_with_ps(estado_id: 2)
      pedido_vm = create_pedido_with_ps(estado_id: 2)
      pedido_vm.update_column(:venta_mostrador, true)

      query = described_class.new(user: admin_user, venta_mostrador: 'false')
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(pedido_normal.id)
      expect(results.map(&:id)).not_to include(pedido_vm.id)
    end

    it 'returns only VM pedidos when venta_mostrador is true' do
      pedido_normal = create_pedido_with_ps(estado_id: 2)
      pedido_vm = create_pedido_with_ps(estado_id: 2)
      pedido_vm.update_column(:venta_mostrador, true)

      query = described_class.new(user: admin_user, venta_mostrador: 'true')
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(pedido_vm.id)
      expect(results.map(&:id)).not_to include(pedido_normal.id)
    end

    it 'returns all pedidos when venta_mostrador is nil' do
      pedido_normal = create_pedido_with_ps(estado_id: 2)
      pedido_vm = create_pedido_with_ps(estado_id: 2)
      pedido_vm.update_column(:venta_mostrador, true)

      query = described_class.new(user: admin_user)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(pedido_normal.id, pedido_vm.id)
    end
  end

  # Step 5 of the shared-clientes migration: cliente users see their pedidos
  # across ALL tiendas they're linked to, not only their tienda_activa.
  describe 'cliente cross-tienda visibility' do
    let(:tienda_b) { create(:tienda, carrito_de_compras: true) }

    before { cliente.tiendas << tienda_b }

    it 'returns the cliente user pedidos placed in the active tienda' do
      pedido_active = create_pedido_with_ps(estado_id: 2, autor: cliente_user, usuario: cliente_user)
      query = described_class.new(user: cliente_user)
      expect(query.base_query.map(&:id)).to include(pedido_active.id)
    end

    it 'also returns the cliente user pedidos placed in another tienda the cliente shares' do
      pedido_other = create_pedido_with_ps(
        estado_id: 2,
        tienda: tienda_b,
        autor: cliente_user,
        usuario: cliente_user
      )
      query = described_class.new(user: cliente_user)
      expect(query.base_query.map(&:id)).to include(pedido_other.id)
    end

    it 'does NOT return pedidos from a tienda the cliente is not linked to' do
      foreign_tienda = create(:tienda)
      foreign_cliente = create(:cliente, tienda: foreign_tienda)
      foreign_cuenta = create(:cuenta, cliente: foreign_cliente)
      foreign_user = create(:usuario, :cliente, cuenta: foreign_cuenta,
                                                visualizando_tienda: foreign_tienda,
                                                tienda_cliente: foreign_tienda)
      pedido_foreign = create_pedido_with_ps(
        estado_id: 2,
        tienda: foreign_tienda,
        cuenta: foreign_cuenta,
        autor: foreign_user,
        usuario: foreign_user
      )
      query = described_class.new(user: cliente_user)
      expect(query.base_query.map(&:id)).not_to include(pedido_foreign.id)
    end
  end

  describe '#footer_aggregates' do
    context 'when productos have peso (pesable products)' do
      it 'includes peso in the importe_total calculation' do
        prod_pesable = create(:producto, tienda: tienda, categoria: categoria, pesable: true)
        prod_normal = create(:producto, tienda: tienda, categoria: categoria, pesable: false)

        # Create pedido with pesable product (peso=2.5, qty=1, price=100) and normal product (qty=3, price=20)
        pedido = Pedidos::Pedido.new(
          tienda: tienda, cuenta: cuenta, fecha: Date.current,
          estado_id: 2, autor: admin_user, usuario: admin_user
        )
        pedido.save(validate: false)

        ps1 = Productos::ProductoSolicitado.new(
          pedido: pedido, producto: prod_pesable, cantidad: 1, peso: 2.5, precio_unitario: 100.0, precio_con_descuento: 100.0
        )
        ps1.save(validate: false)

        ps2 = Productos::ProductoSolicitado.new(
          pedido: pedido, producto: prod_normal, cantidad: 3, precio_unitario: 20.0, precio_con_descuento: 20.0
        )
        ps2.save(validate: false)

        # Ruby calculation: (1 * 2.5 * 100) + (3 * 20) = 250 + 60 = 310
        expect(pedido.reload.importe_total.to_f).to eq(310.0)

        # SQL footer_aggregates should match
        query = described_class.new(user: admin_user)
        footer = query.footer_aggregates
        expect(footer[:importe_total]).to eq(310.0)
      end
    end

    context 'when productos_solicitados have NULL precio_con_descuento (legacy data)' do
      it 'falls back to precio_unitario in the importe_total calculation' do
        # Create pedido with two products, one with NULL precio_con_descuento
        pedido = Pedidos::Pedido.new(
          tienda: tienda, cuenta: cuenta, fecha: Date.current,
          estado_id: 2, autor: admin_user, usuario: admin_user
        )
        pedido.save(validate: false)

        prod1 = create(:producto, tienda: tienda, categoria: categoria)
        ps1 = Productos::ProductoSolicitado.new(
          pedido: pedido, producto: prod1, cantidad: 1, precio_unitario: 100.0, precio_con_descuento: 100.0
        )
        ps1.save(validate: false)

        prod2 = create(:producto, tienda: tienda, categoria: categoria)
        ps2 = Productos::ProductoSolicitado.new(
          pedido: pedido, producto: prod2, cantidad: 5, precio_unitario: 50.0
        )
        ps2.save(validate: false)
        ps2.update_column(:precio_con_descuento, nil) # Simulate legacy data

        # Ruby calculation uses precio_efectivo which has fallback: (1 * 100) + (5 * 50) = 350
        expect(pedido.reload.importe_total.to_f).to eq(350.0)

        # SQL footer_aggregates should match using COALESCE fallback
        query = described_class.new(user: admin_user)
        footer = query.footer_aggregates
        expect(footer[:importe_total]).to eq(350.0)
      end
    end
  end
end
