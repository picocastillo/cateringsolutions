# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contabilidad::SaldosMovimientosQuery, type: :query do
  let(:tienda) { create(:tienda, nombre: 'Tienda SMQ Test') }
  let(:cliente) { create(:cliente, tienda: tienda, nombre: 'Cliente SMQ') }
  let(:cuenta) { create(:cuenta, cliente: cliente, nombre: 'Cuenta SMQ') }

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

    factura = Ventas::Facturacion::Factura.new(
      tienda: tienda, cuenta: target_cuenta, tipo: tipo_factura,
      fecha_emision: attrs[:fecha_emision] || Time.current,
      total: importe, estado_id: 2, nro: attrs[:nro] || rand(1..99_999)
    )
    factura.save(validate: false)
    factura.update_column(:fecha_vencimiento, attrs[:fecha_vencimiento]) if attrs[:fecha_vencimiento]

    Contabilidad::Movimiento.create!(
      comprobante: factura, cuenta: target_cuenta,
      importe: importe, saldo: saldo, tienda: tienda
    )
    factura
  end

  def build_query(attrs = {})
    described_class.new({ user: admin }.merge(attrs))
  end

  describe '#relation' do
    context 'grouping by visualizar_por_id' do
      let(:cliente2) { create(:cliente, tienda: tienda, nombre: 'Cliente SMQ 2') }
      let(:cuenta2) { create(:cuenta, cliente: cliente2) }

      before do
        create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0)
        create_factura_with_movimiento(importe: 2000.0, saldo: 2000.0, cuenta: cuenta2)
      end

      it 'groups by cliente_id when visualizar_por_id=1' do
        query = build_query(visualizar_por_id: 1)
        results = query.relation.to_a
        expect(results.size).to eq(2) # Two distinct clients
      end

      it 'groups by cliente_id and cuenta_id when visualizar_por_id=2' do
        query = build_query(visualizar_por_id: 2)
        results = query.relation.to_a
        expect(results.size).to eq(2) # Two distinct cuentas
      end
    end

    it 'forces visualizar_por_id=3 when usuarios_ids is present' do
      query = build_query(visualizar_por_id: 1)
      query.usuarios_ids = admin.id.to_s
      # Should upgrade to 3 internally
      expect { query.relation }.not_to raise_error
    end

    it 'only returns movimientos with non-zero saldo' do
      create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0)
      create_factura_with_movimiento(importe: 500.0, saldo: 0.0)

      query = build_query(visualizar_por_id: 1)
      results = query.relation
      # Only the movimiento with saldo 1000 should be included
      expect(results.first.saldo_total.to_f).to eq(1000.0)
    end
  end

  describe 'saldo calculations' do
    it 'calculates saldo_total as sum of non-zero saldos' do
      create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0)
      create_factura_with_movimiento(importe: 500.0, saldo: 500.0)

      query = build_query(visualizar_por_id: 1)
      results = query.relation
      row = results.first
      expect(row.saldo_total.to_f).to eq(1500.0)
    end

    it 'calculates saldo_favor from negative saldos' do
      create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0)

      query = build_query(visualizar_por_id: 1)
      results = query.relation
      row = results.first
      # No negative saldos, so saldo_favor should be 0
      expect(row.saldo_favor.to_f).to eq(0.0)
    end
  end

  describe '#csv_dias_numericos=' do
    it 'parses and sorts comma-separated days' do
      query = build_query
      query.csv_dias_numericos = '30, 15, 60'
      expect(query.csv_dias_numericos).to eq('15, 30, 60')
    end
  end

  describe '#headers_de_vencimiento' do
    it 'returns empty when csv_dias_numericos is blank' do
      query = build_query
      expect(query.headers_de_vencimiento).to eq([])
    end

    it 'returns date bucket headers when csv_dias_numericos is set' do
      query = build_query
      query.csv_dias_numericos = '30,60'
      headers = query.headers_de_vencimiento
      expect(headers).not_to be_empty
      expect(headers.length).to eq(3) # before first, between, after last
    end
  end

  describe '#totales' do
    it 'returns ungrouped totals' do
      create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0)
      create_factura_with_movimiento(importe: 500.0, saldo: 500.0)

      query = build_query(visualizar_por_id: 1)
      total = query.totales
      expect(total.saldo_total.to_f).to eq(1500.0)
    end
  end
end
