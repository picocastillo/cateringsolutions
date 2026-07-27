require 'rails_helper'

# Old implementation (N+1 version) extracted as a standalone method for comparison
module ConfirmarPedidosOld
  def self.collect_pedido_ids
    cuentas = Clientes::Cuenta
              .joins(:cliente, :pedidos)
              .merge(Clientes::Cliente.active)
              .where(pedidos: { estado_id: 2 })
              .select('cuentas.id, cuentas.horario_corte_pedidos, cuentas.cliente_id')
              .distinct

    ids = []
    cuentas.each do |cuenta|
      cuenta_with_cliente = Clientes::Cuenta.includes(:cliente).find(cuenta.id)
      cutoff_date = cuenta_with_cliente.proximo_dia_pedido

      pedido_ids = Pedidos::Pedido
                   .where(cuenta_id: cuenta.id)
                   .where(estado_id: 2)
                   .where(pedidos: { fecha: ...cutoff_date })
                   .pluck(:id)

      ids.concat(pedido_ids)
    end
    ids.sort
  end
end

# New implementation (single SQL query) extracted for comparison
module ConfirmarPedidosNew
  def self.collect_pedido_ids
    Pedidos::Pedido
      .joins(cuenta: :cliente)
      .merge(Clientes::Cliente.active)
      .where(pedidos: { estado_id: 2 })
      .where(<<~SQL.squish)
        pedidos.fecha < CASE
          WHEN CURTIME() >= STR_TO_DATE(
            COALESCE(NULLIF(cuentas.horario_corte_pedidos, ''), clientes.horario_corte_pedidos), '%H:%i')
          THEN
            CASE DAYOFWEEK(CURDATE() + INTERVAL 1 DAY)
              WHEN 1 THEN CURDATE() + INTERVAL 2 DAY
              WHEN 7 THEN CURDATE() + INTERVAL 3 DAY
              ELSE CURDATE() + INTERVAL 1 DAY
            END
          ELSE
            CASE DAYOFWEEK(CURDATE())
              WHEN 1 THEN CURDATE() + INTERVAL 1 DAY
              WHEN 7 THEN CURDATE() + INTERVAL 2 DAY
              ELSE CURDATE()
            END
        END
      SQL
      .pluck(:id)
      .sort
  end
end

RSpec.describe 'confirmar_pedidos_aceptados: old vs new', type: :model do
  let!(:tienda) { create(:tienda) }
  let!(:usuario) do
    create(:usuario, :admin, tienda_cliente: tienda, visualizando_tienda: tienda).tap do |u|
      u.tiendas << tienda unless u.tiendas.include?(tienda)
    end
  end
  let!(:categoria) { create(:categoria, tienda: tienda, stock_activo: true) }
  let!(:producto) { create(:producto, tienda: tienda, categoria: categoria) }
  let!(:local) do
    create(:local, tienda: tienda, nombre: 'Local Bench', domicilio: 'Calle 123', telefono: '111')
  end

  before do
    stock = producto.stocks.first || producto.stocks.create!(tienda: tienda, local: local)
    stock.update!(cantidad_actual: 9999, cantidad_minima: 0)
  end

  def create_aceptado_pedido(cuenta, fecha:)
    pedido = build(:pedido,
                   tienda: tienda, cuenta: cuenta, fecha: fecha,
                   estado_id: 1, autor: usuario, usuario: usuario, local: local)
    pedido.asignar_cuenta_manual
    pedido.cuenta = cuenta
    ps = build(:producto_solicitado, pedido: pedido, producto: producto, cantidad: 1, precio_unitario: 100)
    pedido.productos_solicitados << ps
    pedido.save!
    pedido.update_column(:estado_id, 2)
    pedido
  end

  # ── Scenario 1: Simple — cuenta inherits cliente hora_corte (past) ──
  context 'cuenta inherits cliente past hora_corte' do
    let!(:cliente) { create(:cliente, tienda: tienda, horario_corte_pedidos: 1.minute.ago.strftime('%H:%M')) }
    let!(:cuenta)  { create(:cuenta, cliente: cliente) } # no override
    let!(:pedido)  { create_aceptado_pedido(cuenta, fecha: Date.current) }

    it 'both return same pedido' do
      old_ids = ConfirmarPedidosOld.collect_pedido_ids
      new_ids = ConfirmarPedidosNew.collect_pedido_ids
      expect(new_ids).to eq(old_ids)
      expect(new_ids).to include(pedido.id)
    end
  end

  # ── Scenario 2: Cuenta overrides with past hora_corte, cliente is future ──
  context 'cuenta overrides past, cliente future' do
    let!(:cliente) { create(:cliente, tienda: tienda, horario_corte_pedidos: 5.minutes.from_now.strftime('%H:%M')) }
    let!(:cuenta)  { create(:cuenta, cliente: cliente, horario_corte_pedidos: 1.minute.ago.strftime('%H:%M')) }
    let!(:pedido)  { create_aceptado_pedido(cuenta, fecha: Date.current) }

    it 'both include pedido (cuenta override triggers cutoff)' do
      old_ids = ConfirmarPedidosOld.collect_pedido_ids
      new_ids = ConfirmarPedidosNew.collect_pedido_ids
      expect(new_ids).to eq(old_ids)
      expect(new_ids).to include(pedido.id)
    end
  end

  # ── Scenario 3: Cuenta inherits future hora_corte from cliente — NOT eligible ──
  context 'cuenta inherits future hora_corte' do
    let!(:cliente) { create(:cliente, tienda: tienda, horario_corte_pedidos: 5.minutes.from_now.strftime('%H:%M')) }
    let!(:cuenta)  { create(:cuenta, cliente: cliente) }
    # Use next weekday to avoid today being cutoff date
    let(:next_weekday) do
      d = Date.current + 1.day
      d += 1.day while d.saturday? || d.sunday?
      d
    end
    let!(:pedido) { create_aceptado_pedido(cuenta, fecha: next_weekday) }

    it 'both exclude pedido (hora_corte not yet passed)' do
      old_ids = ConfirmarPedidosOld.collect_pedido_ids
      new_ids = ConfirmarPedidosNew.collect_pedido_ids
      expect(new_ids).to eq(old_ids)
      expect(new_ids).not_to include(pedido.id)
    end
  end

  # ── Scenario 4: Far future pedido — never eligible ──
  context 'pedido fecha far in future' do
    let!(:cliente) { create(:cliente, tienda: tienda, horario_corte_pedidos: 1.minute.ago.strftime('%H:%M')) }
    let!(:cuenta)  { create(:cuenta, cliente: cliente) }
    let!(:pedido)  { create_aceptado_pedido(cuenta, fecha: Date.current + 1.week) }

    it 'both exclude future pedido' do
      old_ids = ConfirmarPedidosOld.collect_pedido_ids
      new_ids = ConfirmarPedidosNew.collect_pedido_ids
      expect(new_ids).to eq(old_ids)
      expect(new_ids).not_to include(pedido.id)
    end
  end

  # ── Scenario 5: Discontinued cliente — excluded ──
  context 'discontinued cliente' do
    let!(:cliente) do
      c = create(:cliente, tienda: tienda, horario_corte_pedidos: 1.minute.ago.strftime('%H:%M'))
      c.discontinue!
      c
    end
    let!(:cuenta) { create(:cuenta, cliente: cliente) }
    let!(:pedido) { create_aceptado_pedido(cuenta, fecha: Date.current) }

    it 'both exclude discontinued clientes' do
      old_ids = ConfirmarPedidosOld.collect_pedido_ids
      new_ids = ConfirmarPedidosNew.collect_pedido_ids
      expect(new_ids).to eq(old_ids)
      expect(new_ids).not_to include(pedido.id)
    end
  end

  # ── Scenario 6: Non-aceptado pedido — excluded ──
  context 'confirmado pedido (not aceptado)' do
    let!(:cliente) { create(:cliente, tienda: tienda, horario_corte_pedidos: 1.minute.ago.strftime('%H:%M')) }
    let!(:cuenta)  { create(:cuenta, cliente: cliente) }
    let!(:pedido) do
      p = create_aceptado_pedido(cuenta, fecha: Date.current)
      p.update_column(:estado_id, 3) # confirmado
      p
    end

    it 'both exclude non-aceptado' do
      old_ids = ConfirmarPedidosOld.collect_pedido_ids
      new_ids = ConfirmarPedidosNew.collect_pedido_ids
      expect(new_ids).to eq(old_ids)
      expect(new_ids).not_to include(pedido.id)
    end
  end

  # ── Scenario 7: Mixed — multiple cuentas, some with override, some without ──
  context 'mixed scenario with many cuentas' do
    let!(:cliente_past) { create(:cliente, tienda: tienda, horario_corte_pedidos: 1.minute.ago.strftime('%H:%M')) }
    let!(:cliente_future) { create(:cliente, tienda: tienda, horario_corte_pedidos: 5.minutes.from_now.strftime('%H:%M')) }

    # Cuenta A: inherits past → eligible
    let!(:cuenta_a) { create(:cuenta, cliente: cliente_past) }
    let!(:pedido_a) { create_aceptado_pedido(cuenta_a, fecha: Date.current) }

    # Cuenta B: overrides with past on future cliente → eligible
    let!(:cuenta_b) { create(:cuenta, cliente: cliente_future, horario_corte_pedidos: 1.minute.ago.strftime('%H:%M')) }
    let!(:pedido_b) { create_aceptado_pedido(cuenta_b, fecha: Date.current) }

    # Cuenta C: inherits future → NOT eligible (fecha is next week)
    let!(:cuenta_c) { create(:cuenta, cliente: cliente_future) }
    let(:next_weekday) do
      d = Date.current + 1.day
      d += 1.day while d.saturday? || d.sunday?
      d
    end
    let!(:pedido_c) { create_aceptado_pedido(cuenta_c, fecha: next_weekday) }

    # Cuenta D: inherits past, but pedido is far future → NOT eligible
    let!(:cuenta_d) { create(:cuenta, cliente: cliente_past) }
    let!(:pedido_d) { create_aceptado_pedido(cuenta_d, fecha: Date.current + 2.weeks) }

    it 'both return exactly the same set of eligible pedidos' do
      old_ids = ConfirmarPedidosOld.collect_pedido_ids
      new_ids = ConfirmarPedidosNew.collect_pedido_ids

      expect(new_ids).to eq(old_ids), lambda {
        "MISMATCH!\n  Old: #{old_ids}\n  New: #{new_ids}\n  " \
          "Only in old: #{old_ids - new_ids}\n  Only in new: #{new_ids - old_ids}"
      }
      expect(new_ids).to include(pedido_a.id, pedido_b.id)
      expect(new_ids).not_to include(pedido_c.id, pedido_d.id)
    end
  end
end
