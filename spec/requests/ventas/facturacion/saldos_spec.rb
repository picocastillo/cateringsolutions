# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ventas::Facturacion::Saldos', type: :request do
  let(:tienda) { create(:tienda, nombre: 'Tienda Saldos Test') }
  let(:cliente) { create(:cliente, tienda: tienda, nombre: 'Cliente Saldos') }
  let(:cuenta) { create(:cuenta, cliente: cliente, nombre: 'Cuenta Saldos') }

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

  describe 'GET /saldos' do
    it 'returns HTTP 200' do
      get saldos_path
      expect(response).to have_http_status(:ok)
    end

    it 'renders the saldos index page' do
      get saldos_path
      expect(response.body).to include('Saldos')
      expect(response.body).to include('index-saldos')
    end

    context 'default visualizar_por_id filter' do
      it 'defaults to Clientes (1) on initial load' do
        get saldos_path
        expect(response).to have_http_status(:ok)
        # The dropdown should have value 1 selected
        expect(response.body).to include('Clientes')
      end

      it 'preserves user-selected visualizar_por_id when filtering' do
        get saldos_path, params: { q: { visualizar_por_id: 2 } }
        expect(response).to have_http_status(:ok)
      end

      it 'respects q params and does not override visualizar_por_id' do
        get saldos_path, params: { q: { visualizar_por_id: 3 } }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with movimientos having saldo' do
      before do
        create_factura_with_movimiento(importe: 5000.0, saldo: 5000.0)
      end

      it 'shows saldos for movimientos with non-zero saldo' do
        get saldos_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('5.000')
      end

      it 'does not show fully paid movimientos' do
        create_factura_with_movimiento(importe: 3000.0, saldo: 0.0)
        get saldos_path
        expect(response).to have_http_status(:ok)
        # saldo 0 should be filtered out by query's where('saldo <> 0')
      end
    end

    context 'multi-tenant scoping' do
      it 'does not show saldos from other tiendas' do
        other_tienda = create(:tienda, nombre: 'Other Tienda Saldos')
        other_cliente = create(:cliente, tienda: other_tienda)
        other_cuenta = create(:cuenta, cliente: other_cliente)
        other_factura = Ventas::Facturacion::Factura.new(
          tienda: other_tienda, cuenta: other_cuenta, tipo: tipo_factura,
          fecha_emision: Time.current, total: 8888.0, estado_id: 2, nro: 88_888
        )
        other_factura.save(validate: false)
        Contabilidad::Movimiento.create!(
          comprobante: other_factura, cuenta: other_cuenta,
          importe: 8888.0, saldo: 8888.0, tienda: other_tienda
        )

        # Create one in our tienda
        create_factura_with_movimiento(importe: 5000.0, saldo: 5000.0)

        get saldos_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('5.000')
        expect(response.body).not_to include('8.888')
      end
    end

    context 'grouping' do
      let(:cliente2) { create(:cliente, tienda: tienda, nombre: 'Cliente Saldos 2') }
      let(:cuenta2) { create(:cuenta, cliente: cliente2) }

      before do
        create_factura_with_movimiento(importe: 1000.0, saldo: 1000.0)
        create_factura_with_movimiento(importe: 2000.0, saldo: 2000.0, cuenta: cuenta2)
      end

      it 'groups by cliente on initial load (visualizar_por_id=1)' do
        get saldos_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(cliente.nombre)
        expect(response.body).to include(cliente2.nombre)
      end

      it 'groups by cliente and cuenta when visualizar_por_id=2' do
        get saldos_path, params: { q: { visualizar_por_id: 2 } }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(cliente.nombre)
      end
    end
  end
end
