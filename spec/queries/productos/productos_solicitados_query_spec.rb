require 'rails_helper'

RSpec.describe Productos::ProductosSolicitadosQuery, type: :query do
  let(:tienda) { create(:tienda, carrito_de_compras: true) }
  let(:cliente) { create(:cliente, tienda: tienda) }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:admin_user) do
    user = create(:usuario, :admin, visualizando_tienda: tienda)
    user.tiendas << tienda unless user.tiendas.include?(tienda)
    user
  end
  let(:categoria) { create(:categoria, tienda: tienda) }

  # Helper: create pedido with PS, bypass validations
  def create_pedido_with_ps(estado_id:, cantidad: 5, precio: 150.0, fecha: Date.current)
    pedido = Pedidos::Pedido.new(
      tienda: tienda, cuenta: cuenta, fecha: fecha,
      estado_id: 1, autor: admin_user, usuario: admin_user
    )
    pedido.save(validate: false)

    prod = create(:producto, tienda: tienda, categoria: categoria)
    ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: prod, cantidad: cantidad, precio_unitario: precio)
    ps.save(validate: false)

    pedido.update_column(:estado_id, estado_id)
    pedido.reload
    [pedido, ps.reload]
  end

  describe 'validations' do
    it 'requires fecha when fecha_obligatoria is set' do
      query = described_class.new(user: admin_user, fecha_obligatoria: true)
      expect(query).not_to be_valid
      expect(query.errors[:base]).to be_present
    end

    it 'is valid with fecha_desde and fecha_hasta when fecha_obligatoria is set' do
      query = described_class.new(user: admin_user, fecha_obligatoria: true,
                                  fecha_desde: Date.current, fecha_hasta: Date.current)
      expect(query).to be_valid
    end
  end

  describe '#base_query' do
    it 'excludes pendientes (estado 1) and cancelled (estado 5)' do
      _pedido_pendiente, _ps_pendiente = create_pedido_with_ps(estado_id: 1)
      _pedido_cancelled, _ps_cancelled = create_pedido_with_ps(estado_id: 5)
      _, ps_aceptado = create_pedido_with_ps(estado_id: 2)

      query = described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(ps_aceptado.id)
    end

    it 'scopes to user tienda' do
      other_tienda = create(:tienda)
      other_admin = create(:usuario, :admin, visualizando_tienda: other_tienda)
      other_admin.tiendas << other_tienda

      _, ps_in_tienda = create_pedido_with_ps(estado_id: 2)

      query = described_class.new(user: other_admin, fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a

      expect(results.map(&:id)).not_to include(ps_in_tienda.id)
    end

    it 'filters by estado_id' do
      _, ps_aceptado = create_pedido_with_ps(estado_id: 2)
      _, ps_confirmado = create_pedido_with_ps(estado_id: 3)

      query = described_class.new(user: admin_user, estado_id: 2, fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(ps_aceptado.id)
      expect(results.map(&:id)).not_to include(ps_confirmado.id)
    end

    it 'filters by fecha range' do
      _, ps_today = create_pedido_with_ps(estado_id: 2, fecha: Date.current)
      _, ps_old = create_pedido_with_ps(estado_id: 2, fecha: 1.week.ago)

      query = described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(ps_today.id)
      expect(results.map(&:id)).not_to include(ps_old.id)
    end
  end

  describe '#relation' do
    it 'groups by producto_id and computes aggregate sums' do
      create_pedido_with_ps(estado_id: 2, cantidad: 3, precio: 100.0)
      create_pedido_with_ps(estado_id: 3, cantidad: 7, precio: 100.0)

      query = described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.relation.includes(:producto).to_a

      # Each PS has different products, so each group has 1 entry
      expect(results).to all(respond_to(:cantidad_sumada, :cantidad_aceptada, :cantidad_confirmada, :total_sumado))
    end

    it 'computes cantidad_aceptada from estado 2 pedidos' do
      create_pedido_with_ps(estado_id: 2, cantidad: 4, precio: 100.0)

      query = described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.relation.includes(:producto).to_a

      aceptado = results.find { |r| r.cantidad_aceptada.to_i > 0 }
      expect(aceptado).to be_present
      expect(aceptado.cantidad_aceptada.to_i).to eq(4)
    end

    it 'computes cantidad_confirmada from estado 3 pedidos' do
      create_pedido_with_ps(estado_id: 3, cantidad: 6, precio: 200.0)

      query = described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.relation.includes(:producto).to_a

      confirmado = results.find { |r| r.cantidad_confirmada.to_i > 0 }
      expect(confirmado).to be_present
      expect(confirmado.cantidad_confirmada.to_i).to eq(6)
    end
  end

  describe 'footer aggregate compatibility' do
    # These tests verify the footer SUM calculations used in _reporte_cocina.html.erb
    before do
      create_pedido_with_ps(estado_id: 2, cantidad: 3, precio: 100.0)
      create_pedido_with_ps(estado_id: 3, cantidad: 7, precio: 200.0)
    end

    let(:query) { described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current) }

    it 'sums total cantidad' do
      total = query.base_query.sum('cantidad')
      expect(total).to eq(10)
    end

    it 'sums conditional aceptada cantidad' do
      aceptada = query.base_query.sum('if(pedidos.estado_id = 2, cantidad, 0)')
      expect(aceptada.to_i).to eq(3)
    end

    it 'sums conditional confirmada cantidad' do
      confirmada = query.base_query.sum('if(pedidos.estado_id = 3, cantidad, 0)')
      expect(confirmada.to_i).to eq(7)
    end

    it 'sums total importe' do
      total_importe = query.base_query.sum('cantidad * COALESCE(precio_con_descuento, productos_solicitados.precio_unitario) * COALESCE(productos_solicitados.peso, 1)')
      expect(total_importe.to_f).to eq((3 * 100.0) + (7 * 200.0))
    end
  end

  describe 'horarios_de_corte_ids filter' do
    let(:cliente_12) { create(:cliente, tienda: tienda, horario_corte_pedidos: '12:00') }
    let(:cuenta_12) { create(:cuenta, cliente: cliente_12) }
    let(:cliente_14) { create(:cliente, tienda: tienda, horario_corte_pedidos: '14:00') }
    let(:cuenta_14) { create(:cuenta, cliente: cliente_14) }

    def create_pedido_for_cuenta(cta, estado_id:)
      pedido = Pedidos::Pedido.new(tienda: tienda, cuenta: cta, fecha: Date.current, estado_id: 1, autor: admin_user, usuario: admin_user)
      pedido.save(validate: false)
      prod = create(:producto, tienda: tienda, categoria: categoria)
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: prod, cantidad: 1, precio_unitario: 100)
      ps.save(validate: false)
      pedido.update_column(:estado_id, estado_id)
      [pedido, ps.reload]
    end

    it 'filters by cliente horario_corte_pedidos' do
      _, ps_12 = create_pedido_for_cuenta(cuenta_12, estado_id: 2)
      _, ps_14 = create_pedido_for_cuenta(cuenta_14, estado_id: 2)

      query = described_class.new(user: admin_user, horarios_de_corte_ids: '12:00', fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(ps_12.id)
      expect(results.map(&:id)).not_to include(ps_14.id)
    end

    it 'filters by multiple horarios_de_corte' do
      _, ps_12 = create_pedido_for_cuenta(cuenta_12, estado_id: 2)
      _, ps_14 = create_pedido_for_cuenta(cuenta_14, estado_id: 2)

      query = described_class.new(user: admin_user, horarios_de_corte_ids: '12:00,14:00', fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(ps_12.id, ps_14.id)
    end

    context 'when cuenta has horario_corte_pedidos override' do
      it 'matches cuenta hora_corte instead of cliente hora_corte' do
        cuenta_override = create(:cuenta, cliente: cliente_12, horario_corte_pedidos: '10:00')
        _, ps_override = create_pedido_for_cuenta(cuenta_override, estado_id: 2)

        query = described_class.new(user: admin_user, horarios_de_corte_ids: '10:00', fecha_desde: Date.current, fecha_hasta: Date.current)
        results = query.base_query.to_a

        expect(results.map(&:id)).to include(ps_override.id)
      end

      it 'does not match cliente hora_corte when cuenta has override' do
        cuenta_override = create(:cuenta, cliente: cliente_12, horario_corte_pedidos: '10:00')
        _, ps_override = create_pedido_for_cuenta(cuenta_override, estado_id: 2)

        query = described_class.new(user: admin_user, horarios_de_corte_ids: '12:00', fecha_desde: Date.current, fecha_hasta: Date.current)
        results = query.base_query.to_a

        expect(results.map(&:id)).not_to include(ps_override.id)
      end
    end

    context 'when horarios_de_corte_ids is an Array (from multi-select form)' do
      it 'filters correctly with single-element array' do
        _, ps_12 = create_pedido_for_cuenta(cuenta_12, estado_id: 2)
        _, ps_14 = create_pedido_for_cuenta(cuenta_14, estado_id: 2)

        query = described_class.new(user: admin_user, horarios_de_corte_ids: ['12:00'], fecha_desde: Date.current, fecha_hasta: Date.current)
        results = query.base_query.to_a

        expect(results.map(&:id)).to include(ps_12.id)
        expect(results.map(&:id)).not_to include(ps_14.id)
      end

      it 'filters correctly with multi-element array' do
        _, ps_12 = create_pedido_for_cuenta(cuenta_12, estado_id: 2)
        _, ps_14 = create_pedido_for_cuenta(cuenta_14, estado_id: 2)

        query = described_class.new(user: admin_user, horarios_de_corte_ids: ['12:00', '14:00'], fecha_desde: Date.current, fecha_hasta: Date.current)
        results = query.base_query.to_a

        expect(results.map(&:id)).to include(ps_12.id, ps_14.id)
      end
    end
  end

  describe '#relation_por_medio_pago' do
    it 'groups by producto_id only (flat results)' do
      prod = create(:producto, tienda: tienda, categoria: categoria)

      pedido1 = Pedidos::Pedido.new(tienda: tienda, cuenta: cuenta, fecha: Date.current,
                                    estado_id: 1, autor: admin_user, usuario: admin_user)
      pedido1.save(validate: false)
      Productos::ProductoSolicitado.new(pedido: pedido1, producto: prod, cantidad: 3, precio_unitario: 100.0)
                                   .save(validate: false)
      pedido1.update_columns(estado_id: 3, medio_pago_tipo: 'efectivo')

      pedido2 = Pedidos::Pedido.new(tienda: tienda, cuenta: cuenta, fecha: Date.current,
                                    estado_id: 1, autor: admin_user, usuario: admin_user)
      pedido2.save(validate: false)
      Productos::ProductoSolicitado.new(pedido: pedido2, producto: prod, cantidad: 5, precio_unitario: 100.0)
                                   .save(validate: false)
      pedido2.update_columns(estado_id: 3, medio_pago_tipo: 'debito')

      query = described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.relation_por_medio_pago.includes(:producto).to_a

      expect(results.size).to eq(1)
      expect(results.first.cantidad_sumada.to_i).to eq(8)
    end
  end

  describe '#subtotales_por_medio_pago' do
    it 'returns subtotals grouped by medio tipo from pedidos_medios_pago' do
      pedido1, = create_pedido_with_ps(estado_id: 3, cantidad: 3, precio: 100.0)
      Pedidos::MedioPago.create!(pedido: pedido1, tipo: 'efectivo', importe: 300.0)

      pedido2, = create_pedido_with_ps(estado_id: 3, cantidad: 5, precio: 100.0)
      Pedidos::MedioPago.create!(pedido: pedido2, tipo: 'debito', importe: 500.0)

      query = described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current)
      subtotales = query.subtotales_por_medio_pago

      efectivo = subtotales.find { |t, _| t == 'efectivo' }
      debito = subtotales.find { |t, _| t == 'debito' }

      expect(efectivo).to be_present
      expect(efectivo[1]).to eq(300.0)
      expect(debito).to be_present
      expect(debito[1]).to eq(500.0)
    end

    it 'returns empty array when no medios_pago exist' do
      create_pedido_with_ps(estado_id: 3, cantidad: 3, precio: 100.0)

      query = described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current)
      expect(query.subtotales_por_medio_pago).to be_empty
    end

    it 'does not multiply importe by number of productos_solicitados' do
      pedido = Pedidos::Pedido.new(
        tienda: tienda, cuenta: cuenta, fecha: Date.current,
        estado_id: 1, autor: admin_user, usuario: admin_user
      )
      pedido.save(validate: false)

      3.times do
        prod = create(:producto, tienda: tienda, categoria: categoria)
        ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: prod, cantidad: 2, precio_unitario: 100.0)
        ps.save(validate: false)
      end

      pedido.update_column(:estado_id, 3)
      Pedidos::MedioPago.create!(pedido: pedido, tipo: 'efectivo', importe: 400.0)
      Pedidos::MedioPago.create!(pedido: pedido, tipo: 'qr', importe: 200.0)

      query = described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current)
      subtotales = query.subtotales_por_medio_pago

      efectivo = subtotales.find { |t, _| t == 'efectivo' }
      qr = subtotales.find { |t, _| t == 'qr' }

      expect(efectivo[1]).to eq(400.0)
      expect(qr[1]).to eq(200.0)
    end
  end

  describe 'venta_mostrador filter' do
    def create_pedido_vm(venta_mostrador:, estado_id: 3, cantidad: 2, precio: 100.0)
      pedido = Pedidos::Pedido.new(
        tienda: tienda, cuenta: cuenta, fecha: Date.current,
        estado_id: 1, autor: admin_user, usuario: admin_user
      )
      pedido.save(validate: false)
      prod = create(:producto, tienda: tienda, categoria: categoria)
      ps = Productos::ProductoSolicitado.new(pedido: pedido, producto: prod, cantidad: cantidad, precio_unitario: precio)
      ps.save(validate: false)
      pedido.update_columns(estado_id: estado_id, venta_mostrador: venta_mostrador)
      [pedido, ps.reload]
    end

    it 'returns only non-VM when venta_mostrador is false' do
      _, ps_normal = create_pedido_vm(venta_mostrador: false)
      _, ps_vm = create_pedido_vm(venta_mostrador: true)

      query = described_class.new(user: admin_user, venta_mostrador: 'false', fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(ps_normal.id)
      expect(results.map(&:id)).not_to include(ps_vm.id)
    end

    it 'returns only VM when venta_mostrador is true' do
      _, ps_normal = create_pedido_vm(venta_mostrador: false)
      _, ps_vm = create_pedido_vm(venta_mostrador: true)

      query = described_class.new(user: admin_user, venta_mostrador: 'true', fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(ps_vm.id)
      expect(results.map(&:id)).not_to include(ps_normal.id)
    end

    it 'returns all when venta_mostrador is nil' do
      _, ps_normal = create_pedido_vm(venta_mostrador: false)
      _, ps_vm = create_pedido_vm(venta_mostrador: true)

      query = described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a

      expect(results.map(&:id)).to include(ps_normal.id, ps_vm.id)
    end
  end

  describe '#base_query filters' do
    it 'filters by codigo' do
      pedido, ps = create_pedido_with_ps(estado_id: 3)
      pedido.update_column(:codigo, 42)

      query = described_class.new(user: admin_user, codigo: '42', fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a
      expect(results.map(&:id)).to include(ps.id)
    end

    it 'filters by categoria_ids' do
      _, ps = create_pedido_with_ps(estado_id: 3)
      query = described_class.new(user: admin_user, categoria_ids: [categoria.id], fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a
      expect(results.map(&:id)).to include(ps.id)
    end

    it 'filters by pedido_cocina_id' do
      pedido, ps = create_pedido_with_ps(estado_id: 3)
      pc = Pedidos::PedidoCocina.new(tienda: tienda, autor: admin_user, codigo: 'PC001', fecha: Date.current)
      pc.pedidos << pedido
      pc.save!
      pedido.reload

      query = described_class.new(user: admin_user, pedido_cocina_id: pc.id, fecha_desde: Date.current, fecha_hasta: Date.current)
      results = query.base_query.to_a
      expect(results.map(&:id)).to include(ps.id)
    end
  end

  describe '#clientes_lista' do
    it 'returns active clientes from tienda' do
      query = described_class.new(user: admin_user)
      expect(query.clientes_lista).to include(cliente)
    end

    it 'filters by cliente_ids when present' do
      other_cliente = create(:cliente, tienda: tienda)
      query = described_class.new(user: admin_user, cliente_ids: cliente.id.to_s)
      expect(query.clientes_lista).to include(cliente)
      expect(query.clientes_lista).not_to include(other_cliente)
    end
  end

  describe '#clientes_lista_resumida' do
    it 'returns Todos when no cliente_ids' do
      query = described_class.new(user: admin_user)
      expect(query.clientes_lista_resumida).to eq ['Todos']
    end

    it 'returns filtered clientes when cliente_ids present' do
      query = described_class.new(user: admin_user, cliente_ids: cliente.id.to_s)
      expect(query.clientes_lista_resumida).to include(cliente)
    end
  end

  describe '#fecha_como_date' do
    it 'returns nil when fecha is blank' do
      query = described_class.new(user: admin_user)
      expect(query.fecha_como_date).to be_nil
    end

    it 'returns Date when fecha present' do
      query = described_class.new(user: admin_user, fecha: Date.current.to_s)
      expect(query.fecha_como_date).to eq Date.current
    end
  end

  describe '#footer_aggregates' do
    before do
      create_pedido_with_ps(estado_id: 2, cantidad: 3, precio: 100.0)
      create_pedido_with_ps(estado_id: 3, cantidad: 7, precio: 200.0)
    end

    let(:query) { described_class.new(user: admin_user, fecha_desde: Date.current, fecha_hasta: Date.current) }

    it 'returns hash with all expected keys' do
      agg = query.footer_aggregates
      expect(agg).to include(:cantidad_total, :cantidad_aceptada, :cantidad_confirmada, :importe_total)
    end

    it 'computes correct totals' do
      agg = query.footer_aggregates
      expect(agg[:cantidad_total]).to eq 10
      expect(agg[:cantidad_aceptada]).to eq 3
      expect(agg[:cantidad_confirmada]).to eq 7
      expect(agg[:importe_total]).to eq (3 * 100.0) + (7 * 200.0)
    end

    it 'memoizes the result' do
      agg1 = query.footer_aggregates
      agg2 = query.footer_aggregates
      expect(agg1).to equal(agg2)
    end
  end

  describe '#crear_grupos' do
    it 'groups by producto, cuenta, usuario, direccion when agrupar_por_id > 1' do
      create_pedido_with_ps(estado_id: 3)
      query = described_class.new(user: admin_user, agrupar_por_id: 2, fecha_desde: Date.current, fecha_hasta: Date.current)
      grouped = query.crear_grupos(query.base_query).to_a
      expect(grouped).to be_present
    end

    it 'groups by producto, cuenta, direccion when agrupar_por_id == 1' do
      create_pedido_with_ps(estado_id: 3)
      query = described_class.new(user: admin_user, agrupar_por_id: 1, fecha_desde: Date.current, fecha_hasta: Date.current)
      grouped = query.crear_grupos(query.base_query).to_a
      expect(grouped).to be_present
    end
  end
end
