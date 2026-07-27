require 'rails_helper'

RSpec.describe Clientes::Cliente, type: :model do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Cliente') }
  let(:cliente) { described_class.new(nombre: 'Cliente Test', cuit: '20294834487', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: tienda) }

  it 'is valid with valid attributes' do
    expect(cliente).to be_valid
  end

  it 'requires nombre' do
    cliente.nombre = nil
    expect(cliente).not_to be_valid
    expect(cliente.errors[:nombre]).to be_present
  end

  it 'allows duplicate nombre across tiendas (uniqueness scope was dropped in Step 8)' do
    cliente.save!
    cliente2 = described_class.new(nombre: 'Cliente Test', cuit: '20294834487', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: tienda)
    expect(cliente2).to be_valid
  end

  it 'requires dia_inicio_ciclo_facturacion' do
    cliente.dia_inicio_ciclo_facturacion = nil
    expect(cliente).not_to be_valid
    expect(cliente.errors[:dia_inicio_ciclo_facturacion]).to be_present
  end

  it 'requires vencimiento_a' do
    cliente.vencimiento_a = nil
    expect(cliente).not_to be_valid
    expect(cliente.errors[:vencimiento_a]).to be_present
  end

  it 'requires cuit to be valid format' do
    cliente.cuit = 'invalid'
    expect(cliente).not_to be_valid
    expect(cliente.errors[:cuit]).to be_present
  end

  it 'requires horario_corte_pedidos to be valid' do
    cliente.horario_corte_pedidos = '25:00'
    expect(cliente).not_to be_valid
    expect(cliente.errors[:horario_corte_pedidos]).to be_present
  end

  it 'to_s returns nombre' do
    expect(cliente.to_s).to eq 'Cliente Test'
  end

  it 'usuarios_alcanzados returns usuarios' do
    expect(cliente.usuarios_alcanzados).to eq cliente.usuarios
  end

  it 'cuenta_principal returns first active cuenta' do
    cliente.save!
    expect(cliente.cuenta_principal).to eq cliente.cuentas.first
  end

  describe 'turnos de entrega' do
    let!(:turno_desayuno) { create(:turno_entrega, :desayuno) }
    let!(:turno_almuerzo) { create(:turno_entrega, :almuerzo) }
    let!(:turno_merienda) { create(:turno_entrega, :merienda, :inactivo) }

    before do
      cliente.save!
      create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_desayuno)
      create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_almuerzo)
      create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_merienda)
    end

    describe '#turnos_activos' do
      it 'returns only active turnos ordered by posicion' do
        turnos = cliente.turnos_activos
        expect(turnos).to include(turno_desayuno, turno_almuerzo)
        expect(turnos).not_to include(turno_merienda)
      end
    end

    describe '#tiene_turno?' do
      it 'returns true for assigned turno' do
        expect(cliente.tiene_turno?(turno_desayuno.id)).to be true
      end

      it 'returns false for non-assigned turno' do
        turno_cena = create(:turno_entrega, codigo: 'cena')
        expect(cliente.tiene_turno?(turno_cena.id)).to be false
      end
    end
  end

  describe '.confirmar_pedidos_aceptados' do
    let!(:tienda) { create(:tienda) }
    let!(:cliente) do
      create(:cliente,
             tienda: tienda,
             horario_corte_pedidos: 1.minute.ago.strftime('%H:%M'),
             cuenta_corriente: true)
    end
    let!(:cuenta) { create(:cuenta, cliente: cliente) }
    let!(:usuario) do
      create(:usuario, :admin,
             cuenta: cuenta,
             tienda_cliente: tienda,
             visualizando_tienda: tienda).tap do |u|
        u.tiendas << tienda unless u.tiendas.include?(tienda)
      end
    end
    let!(:categoria) { create(:categoria, tienda: tienda, stock_activo: true) }
    let!(:producto) { create(:producto, tienda: tienda, categoria: categoria) }
    let!(:local) do
      create(:local,
             tienda: tienda,
             nombre: 'Local Test',
             domicilio: 'Calle Test 123',
             telefono: '123456789')
    end

    before do
      # Create stock for producto
      stock = producto.stocks.first || producto.stocks.create!(tienda: tienda, local: local)
      stock.update!(cantidad_actual: 100, cantidad_minima: 10)
    end

    context 'with pedidos in estado aceptado (2) and fecha < cutoff date' do
      let!(:pedido_aceptado) do
        pedido = build(:pedido,
                       tienda: tienda,
                       cuenta: cuenta,
                       fecha: Date.current,
                       estado_id: 2, # aceptado
                       autor: usuario,
                       usuario: usuario,
                       local: local)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta

        # Create producto_solicitado before saving
        ps = build(:producto_solicitado,
                   pedido: pedido,
                   producto: producto,
                   cantidad: 5,
                   precio_unitario: 100)
        pedido.productos_solicitados << ps
        pedido.save!

        pedido
      end

      it 'queues ConfirmarJob for each eligible pedido' do
        expect(Clientes::ConfirmarJob).to receive(:perform_later).with(pedido_aceptado.id)

        described_class.confirmar_pedidos_aceptados
      end

      it 'processes pedidos from multiple clientes' do
        # Create second cliente with pedido
        cliente2 = create(:cliente,
                          tienda: tienda,
                          horario_corte_pedidos: 1.minute.ago.strftime('%H:%M'),
                          cuenta_corriente: true)
        cuenta2 = create(:cuenta, cliente: cliente2)

        pedido2 = build(:pedido,
                        tienda: tienda,
                        cuenta: cuenta2,
                        fecha: Date.current,
                        estado_id: 2,
                        autor: usuario,
                        usuario: usuario,
                        local: local)
        pedido2.asignar_cuenta_manual
        pedido2.cuenta = cuenta2

        ps2 = build(:producto_solicitado,
                    pedido: pedido2,
                    producto: producto,
                    cantidad: 3,
                    precio_unitario: 100)
        pedido2.productos_solicitados << ps2
        pedido2.save!

        expect(Clientes::ConfirmarJob).to receive(:perform_later).with(pedido_aceptado.id)
        expect(Clientes::ConfirmarJob).to receive(:perform_later).with(pedido2.id)

        described_class.confirmar_pedidos_aceptados
      end
    end

    context 'with pedidos in estado aceptado but fecha >= cutoff date' do
      # Create a fresh cliente with only future pedidos to avoid interference
      let!(:cliente_con_futuro) do
        create(:cliente, tienda: tienda,
                         horario_corte_pedidos: 1.minute.ago.strftime('%H:%M'),
                         cuenta_corriente: true)
      end

      let!(:cuenta_futuro) { create(:cuenta, cliente: cliente_con_futuro) }

      let!(:pedido_futuro) do
        pedido = build(:pedido,
                       tienda: tienda,
                       cuenta: cuenta_futuro,
                       fecha: Date.current + 1.week, # Far enough in the future to be > cutoff
                       estado_id: 2,
                       autor: usuario,
                       usuario: usuario,
                       local: local)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta_futuro

        ps = build(:producto_solicitado,
                   pedido: pedido,
                   producto: producto,
                   cantidad: 5,
                   precio_unitario: 100)
        pedido.productos_solicitados << ps
        pedido.save!

        pedido
      end

      it 'does not queue job for future pedidos' do
        # Should only queue jobs for eligible pedidos (fecha < cutoff)
        # The future pedido should NOT be queued
        # Don't use allow_any_instance_of to avoid masking the actual behavior
        jobs_queued = []
        allow(Clientes::ConfirmarJob).to receive(:perform_later) do |pedido_id|
          jobs_queued << pedido_id
        end

        described_class.confirmar_pedidos_aceptados

        expect(jobs_queued).not_to include(pedido_futuro.id)
      end
    end

    context 'with pedidos not in estado aceptado' do
      let!(:pedido_confirmado) do
        pedido = build(:pedido,
                       tienda: tienda,
                       cuenta: cuenta,
                       fecha: Date.current,
                       estado_id: 3, # confirmado
                       autor: usuario,
                       usuario: usuario,
                       local: local)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta

        ps = build(:producto_solicitado,
                   pedido: pedido,
                   producto: producto,
                   cantidad: 5,
                   precio_unitario: 100)
        pedido.productos_solicitados << ps
        pedido.save!

        pedido
      end

      it 'does not queue job for already confirmed pedidos' do
        expect(Clientes::ConfirmarJob).not_to receive(:perform_later)

        described_class.confirmar_pedidos_aceptados
      end
    end

    context 'with discontinued clientes' do
      before do
        cliente.discontinue!
      end

      let!(:pedido_discontinued) do
        pedido = build(:pedido,
                       tienda: tienda,
                       cuenta: cuenta,
                       fecha: Date.current,
                       estado_id: 2,
                       autor: usuario,
                       usuario: usuario,
                       local: local)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta

        ps = build(:producto_solicitado,
                   pedido: pedido,
                   producto: producto,
                   cantidad: 5,
                   precio_unitario: 100)
        pedido.productos_solicitados << ps
        pedido.save!

        pedido
      end

      it 'does not process pedidos from discontinued clientes' do
        expect(Clientes::ConfirmarJob).not_to receive(:perform_later)

        described_class.confirmar_pedidos_aceptados
      end
    end

    context 'with cuenta-level horario_corte_pedidos override' do
      # Use a weekday for the pedido fecha to avoid weekend edge cases
      let(:next_weekday) do
        d = Date.current + 1.day
        d += 1.day while d.saturday? || d.sunday?
        d
      end

      let!(:cliente_future) do
        create(:cliente,
               tienda: tienda,
               horario_corte_pedidos: 5.minutes.from_now.strftime('%H:%M'),
               cuenta_corriente: true)
      end
      let!(:cuenta_con_override) { create(:cuenta, cliente: cliente_future, horario_corte_pedidos: 1.minute.ago.strftime('%H:%M')) }
      let!(:cuenta_sin_override) { create(:cuenta, cliente: cliente_future) }

      let!(:pedido_override) do
        pedido = build(:pedido,
                       tienda: tienda,
                       cuenta: cuenta_con_override,
                       fecha: Date.current,
                       estado_id: 2,
                       autor: usuario,
                       usuario: usuario,
                       local: local)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta_con_override
        ps = build(:producto_solicitado, pedido: pedido, producto: producto, cantidad: 3, precio_unitario: 100)
        pedido.productos_solicitados << ps
        pedido.save!
        pedido
      end

      let!(:pedido_sin_override) do
        pedido = build(:pedido,
                       tienda: tienda,
                       cuenta: cuenta_sin_override,
                       fecha: next_weekday,
                       estado_id: 2,
                       autor: usuario,
                       usuario: usuario,
                       local: local)
        pedido.asignar_cuenta_manual
        pedido.cuenta = cuenta_sin_override
        ps = build(:producto_solicitado, pedido: pedido, producto: producto, cantidad: 3, precio_unitario: 100)
        pedido.productos_solicitados << ps
        pedido.save!
        pedido
      end

      it 'queues pedido from cuenta with past override hora_corte' do
        jobs_queued = []
        allow(Clientes::ConfirmarJob).to receive(:perform_later) do |pid|
          jobs_queued << pid
        end

        described_class.confirmar_pedidos_aceptados

        expect(jobs_queued).to include(pedido_override.id)
      end

      it 'does not queue pedido from cuenta using cliente future hora_corte' do
        jobs_queued = []
        allow(Clientes::ConfirmarJob).to receive(:perform_later) do |pid|
          jobs_queued << pid
        end

        described_class.confirmar_pedidos_aceptados

        expect(jobs_queued).not_to include(pedido_sin_override.id)
      end
    end
  end

  describe 'limite_compra attributes' do
    it 'defaults limite_compra_pesos to nil' do
      cliente.save!
      expect(cliente.limite_compra_pesos).to be_nil
    end

    it 'defaults limite_compra_dolares to nil' do
      cliente.save!
      expect(cliente.limite_compra_dolares).to be_nil
    end

    it 'can set limite_compra_pesos' do
      cliente.save!
      cliente.update!(limite_compra_pesos: 5000.50)
      expect(cliente.reload.limite_compra_pesos).to eq(5000.50)
    end

    it 'can set limite_compra_dolares' do
      cliente.save!
      cliente.update!(limite_compra_dolares: 100.25)
      expect(cliente.reload.limite_compra_dolares).to eq(100.25)
    end

    it 'can clear limits by setting to nil' do
      cliente.save!
      cliente.update!(limite_compra_pesos: 5000, limite_compra_dolares: 100)
      cliente.update!(limite_compra_pesos: nil, limite_compra_dolares: nil)
      expect(cliente.reload.limite_compra_pesos).to be_nil
      expect(cliente.reload.limite_compra_dolares).to be_nil
    end
  end

  describe '#precios_vigentes' do
    let(:categoria) { create(:categoria, tienda: tienda) }
    let(:producto) { create(:producto, tienda: tienda, categoria: categoria) }
    let(:fecha) { Date.current }

    before { cliente.save! }

    it 'returns precios vigentes for the given fecha' do
      precio = create(:precio, producto: producto, fecha_desde: Date.current - 1.day, fecha_hasta: Date.current + 1.day)
      result = cliente.precios_vigentes(fecha, tienda)
      expect(result.map(&:id)).to include(precio.id)
    end

    it 'excludes expired precios' do
      create(:precio, producto: producto, fecha_desde: Date.current - 10.days, fecha_hasta: Date.current - 1.day)
      result = cliente.precios_vigentes(fecha, tienda)
      expect(result).to be_empty
    end

    it 'excludes future precios' do
      create(:precio, producto: producto, fecha_desde: Date.current + 1.day, fecha_hasta: Date.current + 10.days)
      result = cliente.precios_vigentes(fecha, tienda)
      expect(result).to be_empty
    end

    it 'includes precios with nil fecha_hasta' do
      precio = create(:precio, producto: producto, fecha_desde: Date.current - 1.day, fecha_hasta: nil)
      result = cliente.precios_vigentes(fecha, tienda)
      expect(result.map(&:id)).to include(precio.id)
    end

    it 'excludes precios from discontinuado products' do
      producto.discontinue!
      create(:precio, producto: producto, fecha_desde: Date.current - 1.day, fecha_hasta: Date.current + 1.day)
      result = cliente.precios_vigentes(fecha, tienda)
      expect(result).to be_empty
    end

    it 'excludes precios from menu_diario categories' do
      cat_md = create(:categoria, tienda: tienda, menu_diario: true)
      prod_md = create(:producto, tienda: tienda, categoria: cat_md)
      create(:precio, producto: prod_md, fecha_desde: Date.current - 1.day, fecha_hasta: Date.current + 1.day)
      result = cliente.precios_vigentes(fecha, tienda)
      expect(result).to be_empty
    end

    it 'includes precios linked to this cliente' do
      precio = create(:precio, :for_cliente, producto: producto, cliente: cliente,
                                             fecha_desde: Date.current - 1.day, fecha_hasta: Date.current + 1.day)
      result = cliente.precios_vigentes(fecha, tienda)
      expect(result.map(&:id)).to include(precio.id)
    end

    it 'includes eager loaded associations for producto and categoria' do
      create(:precio, producto: producto, fecha_desde: Date.current - 1.day, fecha_hasta: Date.current + 1.day)
      result = cliente.precios_vigentes(fecha, tienda)
      # Verify includes are present (no N+1 for producto and categoria)
      first = result.first
      expect(first.association(:producto)).to be_loaded
      expect(first.producto.association(:categoria)).to be_loaded
    end
  end
end
