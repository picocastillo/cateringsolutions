# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VentasMostrador::Descuentos', type: :request do
  let(:tienda) do
    create(:tienda,
           nombre: 'Tienda VM Test',
           dominio: 'localhost',
           telefono: '123456789',
           email: 'test@vm.com',
           venta_mostrador: true,
           carrito_de_compras: true)
  end

  let(:admin) do
    user = create(:usuario, :admin,
                  login: 'admin_desc',
                  password: 'password123',
                  password_confirmation: 'password123',
                  nombre: 'Admin',
                  email: 'admin_desc@example.com',
                  visualizando_tienda: tienda)
    user.tiendas << tienda unless user.tiendas.include?(tienda)
    user
  end

  before do
    login_as(admin)
    bypass_authorization
  end

  describe 'GET /ventas_mostrador/descuentos' do
    it 'renders the index page' do
      create(:descuento_venta_mostrador, tienda: tienda, nombre: 'Descuento Test')
      get ventas_mostrador_descuentos_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Descuento Test')
    end
  end

  describe 'GET /ventas_mostrador/descuentos/new' do
    it 'returns JS response with form modal' do
      get new_ventas_mostrador_descuento_path, xhr: true
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/javascript')
    end
  end

  describe 'POST /ventas_mostrador/descuentos' do
    it 'creates a new descuento with valid params' do
      expect do
        post ventas_mostrador_descuentos_path, xhr: true, params: {
          descuento_venta_mostrador: {
            nombre: 'Efectivo 5%', tipo_descuento: 'porcentaje',
            porcentaje: 5, limite_bonificacion: 1000,
            medio_pago_tipo: 'efectivo', importe_minimo: 0
          }
        }
      end.to change(VentasMostrador::DescuentoVentaMostrador, :count).by(1)
      expect(response).to have_http_status(:ok)
    end

    it 'renders errors for invalid params' do
      post ventas_mostrador_descuentos_path, xhr: true, params: {
        descuento_venta_mostrador: {
          nombre: '', tipo_descuento: 'importe', medio_pago_tipo: 'efectivo', importe_minimo: 0
        }
      }
      expect(response).to have_http_status(:ok)
      expect(VentasMostrador::DescuentoVentaMostrador.count).to eq(0)
    end
  end

  describe 'PATCH /ventas_mostrador/descuentos/:id' do
    let!(:descuento) { create(:descuento_venta_mostrador, tienda: tienda) }

    it 'updates the descuento' do
      patch ventas_mostrador_descuento_path(descuento), xhr: true, params: {
        descuento_venta_mostrador: { nombre: 'Nuevo Nombre' }
      }
      expect(response).to have_http_status(:ok)
      expect(descuento.reload.nombre).to eq('Nuevo Nombre')
    end
  end

  describe 'DELETE /ventas_mostrador/descuentos/:id' do
    let!(:descuento) { create(:descuento_venta_mostrador, tienda: tienda) }

    it 'destroys the descuento' do
      expect do
        delete ventas_mostrador_descuento_path(descuento), xhr: true
      end.to change(VentasMostrador::DescuentoVentaMostrador, :count).by(-1)
    end
  end

  describe 'PUT /ventas_mostrador/descuentos/:id/toggle_activo' do
    let!(:descuento) { create(:descuento_venta_mostrador, tienda: tienda, activo: true) }

    it 'toggles activo from true to false' do
      put toggle_activo_ventas_mostrador_descuento_path(descuento)
      expect(descuento.reload.activo).to be false
      expect(response).to redirect_to(ventas_mostrador_descuentos_path)
    end

    it 'toggles activo from false to true' do
      descuento.update!(activo: false)
      put toggle_activo_ventas_mostrador_descuento_path(descuento)
      expect(descuento.reload.activo).to be true
    end
  end
end
