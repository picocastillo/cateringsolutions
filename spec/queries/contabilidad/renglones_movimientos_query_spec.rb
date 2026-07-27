# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contabilidad::RenglonesMovimientosQuery, type: :query do
  let(:tienda) { create(:tienda, nombre: 'Tienda RMQ Test') }
  let(:cliente) { create(:cliente, tienda: tienda, nombre: 'Cliente RMQ') }
  let(:cuenta) { create(:cuenta, cliente: cliente, nombre: 'Cuenta RMQ') }

  let(:admin) do
    user = create(:usuario, :admin, visualizando_tienda: tienda)
    user.tiendas << tienda unless user.tiendas.include?(tienda)
    user
  end

  let(:tipo_factura) do
    Comprobantes::Tipo.find_or_create_by!(codigo: 1) do |t|
      t.desc = 'Factura'
      t.clase = 'Ventas::Facturacion::Factura'
      t.letra = 'A'
      t.debitan = true
    end
  end

  def create_factura_with_movimiento(attrs = {})
    target_cuenta = attrs[:cuenta] || cuenta
    importe = attrs[:importe] || 1000.0
    saldo = attrs[:saldo] || importe
    fecha_emision = attrs[:fecha_emision] || Time.current

    factura = Ventas::Facturacion::Factura.new(
      tienda: tienda, cuenta: target_cuenta, tipo: tipo_factura,
      fecha_emision: fecha_emision, total: importe, estado_id: 2,
      nro: attrs[:nro] || rand(1..99_999)
    )
    factura.save(validate: false)
    factura.update_column(:fecha_vencimiento, attrs[:fecha_vencimiento]) if attrs[:fecha_vencimiento]

    mov = Contabilidad::Movimiento.create!(
      comprobante: factura, cuenta: target_cuenta,
      importe: importe, saldo: saldo, tienda: tienda
    )
    [factura, mov]
  end

  def build_query(attrs = {})
    described_class.new({ user: admin }.merge(attrs))
  end

  describe 'defaults' do
    it 'defaults condicion_eq to Pendientes' do
      query = build_query
      expect(query.condicion_eq).to eq('Pendientes')
    end
  end

  describe '#relation' do
    context 'condicion_eq = Pendientes (default)' do
      it 'only returns movimientos with saldo <> 0' do
        create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0)
        create_factura_with_movimiento(importe: 500.0, saldo: 0.0) # fully paid

        query = build_query
        results = query.relation
        expect(results.count).to eq(1)
        expect(results.first.importe.to_f).to eq(1000.0)
      end
    end

    context 'condicion_eq = Vencidos' do
      it 'only returns movimientos with past-due vencimiento' do
        create_factura_with_movimiento(
          importe: 1000.0, saldo: 1000.0,
          fecha_vencimiento: 1.week.ago.to_date
        )
        create_factura_with_movimiento(
          importe: 2000.0, saldo: 2000.0,
          fecha_vencimiento: 1.week.from_now.to_date
        )

        query = build_query(condicion_eq: 'Vencidos')
        results = query.relation
        expect(results.count).to eq(1)
        expect(results.first.importe.to_f).to eq(1000.0)
      end
    end

    context 'condicion_eq = A Vencer' do
      it 'only returns movimientos with future vencimiento' do
        create_factura_with_movimiento(
          importe: 1000.0, saldo: 1000.0,
          fecha_vencimiento: 1.week.ago.to_date
        )
        create_factura_with_movimiento(
          importe: 2000.0, saldo: 2000.0,
          fecha_vencimiento: 1.week.from_now.to_date
        )

        query = build_query(condicion_eq: 'A Vencer')
        results = query.relation
        expect(results.count).to eq(1)
        expect(results.first.importe.to_f).to eq(2000.0)
      end
    end

    context 'condicion_eq blank (Todos)' do
      it 'returns all movimientos including zero-saldo' do
        create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0)
        create_factura_with_movimiento(importe: 500.0, saldo: 0.0)

        query = build_query(condicion_eq: '')
        results = query.relation
        expect(results.count).to eq(2)
      end
    end

    context 'de_cliente filter' do
      it 'filters by specific cliente' do
        cliente2 = create(:cliente, tienda: tienda, nombre: 'Client 2')
        cuenta2 = create(:cuenta, cliente: cliente2)

        create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0)
        create_factura_with_movimiento(importe: 2000.0, saldo: 2000.0, cuenta: cuenta2)

        query = build_query(de_cliente: cliente.id)
        results = query.relation
        expect(results.count).to eq(1)
        expect(results.first.importe.to_f).to eq(1000.0)
      end
    end

    context 'date filtering' do
      it 'filters by desde' do
        create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0, fecha_emision: 2.months.ago)
        create_factura_with_movimiento(importe: 2000.0, saldo: 2000.0, fecha_emision: 1.week.ago)

        query = build_query(desde: 1.month.ago.to_date)
        results = query.relation
        expect(results.count).to eq(1)
        expect(results.first.importe.to_f).to eq(2000.0)
      end

      it 'filters by hasta' do
        create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0, fecha_emision: 2.months.ago)
        create_factura_with_movimiento(importe: 2000.0, saldo: 2000.0, fecha_emision: 1.week.ago)

        query = build_query(hasta: 1.month.ago.to_date)
        results = query.relation
        expect(results.count).to eq(1)
        expect(results.first.importe.to_f).to eq(1000.0)
      end
    end
  end

  describe '#movimientos_con_saldos' do
    it 'calculates running saldo_cuenta correctly' do
      create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0, fecha_emision: 2.days.ago)
      create_factura_with_movimiento(importe: 500.0, saldo: 500.0, fecha_emision: 1.day.ago)

      query = build_query
      results = query.movimientos_con_saldos(1, 20)
      movs = results.to_a

      expect(movs.size).to eq(2)
      # Running balance: first movimiento + second movimiento
      expect(movs.first.saldo_cuenta).to be_present
      expect(movs.last.saldo_cuenta).to be_present
    end

    it 'returns nil when query is invalid' do
      query = build_query(user: nil)
      result = query.movimientos_con_saldos(1, 20)
      expect(result).to be_nil
    end
  end

  describe '#rango_fecha_amplio?' do
    it 'returns true when desde is blank and condicion is blank' do
      query = build_query(condicion_eq: '')
      expect(query.rango_fecha_amplio?).to be true
    end

    it 'returns false when condicion is present' do
      query = build_query(condicion_eq: 'Pendientes')
      expect(query.rango_fecha_amplio?).to be false
    end

    it 'returns true when date range exceeds 6 months' do
      query = build_query(condicion_eq: '', desde: 1.year.ago.to_date, hasta: Date.current)
      expect(query.rango_fecha_amplio?).to be true
    end

    it 'returns false when date range is within 6 months' do
      query = build_query(condicion_eq: '', desde: 3.months.ago.to_date, hasta: Date.current)
      expect(query.rango_fecha_amplio?).to be false
    end
  end

  describe 'PDF validation (filtros_correctos)' do
    it 'raises error when rango_fecha_amplio with para_pdf true' do
      query = build_query(condicion_eq: '', para_pdf: true)
      expect { query.movimientos_con_saldos(1, 20) }.to raise_error(ErrorAplicacion)
    end

    it 'does not raise when condicion is set' do
      query = build_query(condicion_eq: 'Pendientes', para_pdf: true)
      allow(admin).to receive_messages(admin_complejo?: false, de_cc?: false)
      expect { query.movimientos_con_saldos(1, 20) }.not_to raise_error
    end
  end
end
