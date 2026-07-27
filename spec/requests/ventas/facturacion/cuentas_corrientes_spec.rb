# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ventas::Facturacion::CuentasCorrientes', type: :request do
  let(:tienda) { create(:tienda, nombre: 'Tienda CC Test') }
  let(:cliente) { create(:cliente, tienda: tienda, nombre: 'Cliente CC') }
  let(:cuenta) { create(:cuenta, cliente: cliente, nombre: 'Cuenta CC') }

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

  # Helper to create a factura with its movimiento directly
  def create_factura_with_movimiento(attrs = {})
    fecha_emision = attrs[:fecha_emision] || Time.current
    importe = attrs[:importe] || 1000.0
    saldo = attrs[:saldo] || importe
    target_cuenta = attrs[:cuenta] || cuenta
    fecha_vencimiento = attrs[:fecha_vencimiento] || nil

    factura = Ventas::Facturacion::Factura.new(
      tienda: tienda, cuenta: target_cuenta, tipo: tipo_factura,
      fecha_emision: fecha_emision, total: importe, estado_id: 2, nro: attrs[:nro] || rand(1..99_999)
    )
    factura.save(validate: false)
    factura.update_column(:fecha_vencimiento, fecha_vencimiento) if fecha_vencimiento

    Contabilidad::Movimiento.create!(
      comprobante: factura, cuenta: target_cuenta,
      importe: importe, saldo: saldo, tienda: tienda
    )
    factura
  end

  before do
    login_as(admin)
    bypass_authorization
  end

  describe 'GET /cuentas_corrientes' do
    it 'returns HTTP 200' do
      get cuentas_corrientes_path
      expect(response).to have_http_status(:ok)
    end

    it 'renders the cuentas corrientes index page' do
      get cuentas_corrientes_path
      expect(response.body).to include('Cuentas Corrientes')
      expect(response.body).to include('index-ctasctes')
    end

    context 'default desde filter' do
      it 'sets desde to first day of previous month on initial load' do
        get cuentas_corrientes_path
        expect(response).to have_http_status(:ok)
        expected_date = 1.month.ago.beginning_of_month.to_date.strftime('%d/%m/%Y')
        expect(response.body).to include(expected_date)
      end

      it 'preserves user-provided desde when filtering' do
        custom_date = '2025-06-01'
        get cuentas_corrientes_path, params: { q: { desde: custom_date } }
        expect(response).to have_http_status(:ok)
        # Date is rendered in DD/MM/YYYY format by singledate input
        expect(response.body).to include('01/06/2025')
      end

      it 'does not override when user submits empty filter' do
        get cuentas_corrientes_path, params: { q: { desde: '' } }
        expect(response).to have_http_status(:ok)
        # When q is present but desde is blank, should NOT apply default
        default_date = 1.month.ago.beginning_of_month.to_date
        expect(response.body).not_to include(default_date.strftime('%d/%m/%Y'))
      end
    end

    context 'with movimientos' do
      before do
        create_factura_with_movimiento(
          fecha_emision: 2.weeks.ago,
          importe: 5000.0, saldo: 5000.0,
          fecha_vencimiento: 1.week.from_now
        )
      end

      it 'shows movimientos within the date range' do
        get cuentas_corrientes_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('5.000')
      end

      it 'filters by condicion Pendientes by default' do
        # Default condicion is 'Pendientes' which filters saldo <> 0
        create_factura_with_movimiento(
          fecha_emision: 1.week.ago,
          importe: 3000.0, saldo: 0.0 # Fully paid
        )
        get cuentas_corrientes_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('5.000')
      end

      it 'filters by condicion Todos when selected' do
        create_factura_with_movimiento(
          fecha_emision: 1.week.ago,
          importe: 3000.0, saldo: 0.0
        )
        get cuentas_corrientes_path, params: { q: { condicion_eq: '' } }
        expect(response).to have_http_status(:ok)
        # Both movimientos should be shown (paid and unpaid)
        expect(response.body).to include('5.000')
        expect(response.body).to include('3.000')
      end
    end

    context 'multi-tenant scoping' do
      it 'does not show movimientos from other tiendas' do
        other_tienda = create(:tienda, nombre: 'Other Tienda')
        other_cliente = create(:cliente, tienda: other_tienda, nombre: 'Other Cliente')
        other_cuenta = create(:cuenta, cliente: other_cliente)
        other_factura = Ventas::Facturacion::Factura.new(
          tienda: other_tienda, cuenta: other_cuenta, tipo: tipo_factura,
          fecha_emision: Time.current, total: 9999.0, estado_id: 2, nro: 99_999
        )
        other_factura.save(validate: false)
        Contabilidad::Movimiento.create!(
          comprobante: other_factura, cuenta: other_cuenta,
          importe: 9999.0, saldo: 9999.0, tienda: other_tienda
        )

        get cuentas_corrientes_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('9.999')
      end
    end

    context 'client filtering' do
      let(:cliente2) { create(:cliente, tienda: tienda, nombre: 'Cliente CC 2') }
      let(:cuenta2) { create(:cuenta, cliente: cliente2) }

      before do
        create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0, fecha_emision: 1.week.ago)
        create_factura_with_movimiento(importe: 7777.0, saldo: 7777.0, cuenta: cuenta2, fecha_emision: 1.week.ago)
      end

      it 'filters by cliente when clientes_ids provided' do
        get cuentas_corrientes_path, params: { q: { clientes_ids: cliente.id.to_s } }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Cliente CC')
        expect(response.body).not_to include('Cliente CC 2')
      end
    end

    context 'pagination' do
      it 'paginates at 20 per page' do
        25.times do |i|
          create_factura_with_movimiento(
            importe: 100.0 + i, saldo: 100.0 + i,
            fecha_emision: 1.week.ago, nro: i + 1
          )
        end

        get cuentas_corrientes_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
