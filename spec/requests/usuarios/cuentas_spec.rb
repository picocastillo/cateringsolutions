require 'rails_helper'

RSpec.describe 'Usuarios::Cuentas - Servicio de Impresión', type: :request do
  let(:tienda) { create(:tienda, nombre: 'Tienda Profile Test', carrito_de_compras: true, dominio: 'www.example.com') }
  let(:admin_user) do
    u = create(:usuario, :admin, visualizando_tienda: tienda)
    u.tiendas << tienda unless u.tiendas.include?(tienda)
    u
  end
  let(:cliente_user) do
    cliente = create(:cliente, tienda: tienda)
    cuenta = create(:cuenta, cliente: cliente)
    create(:usuario, :cliente, visualizando_tienda: tienda, cuenta: cuenta)
  end

  describe 'GET /cuenta/edit' do
    context 'as admin' do
      before { login_as(admin_user) }

      it 'shows the Impresión tab' do
        get '/cuenta/edit'
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Impresión')
        expect(response.body).to include('servicio_de_impresion_id')
        expect(response.body).to include('WHB')
        expect(response.body).to include('QZ Tray')
      end
    end

    context 'as cliente' do
      before { login_as(cliente_user) }

      it 'does not show the Impresión tab' do
        get '/cuenta/edit'
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('servicio_de_impresion_id')
      end
    end
  end

  describe 'PUT /cuenta - servicio_de_impresion_id' do
    before { login_as(admin_user) }

    it 'updates the print service preference to QZ Tray' do
      put '/cuenta', params: { usuario: { servicio_de_impresion_id: 2 }, password_anterior: '' }

      admin_user.reload
      expect(admin_user.servicio_de_impresion_id).to eq(2)
      expect(admin_user.servicio_de_impresion).to eq(Usuarios::ServicioDeImpresion[:qztray])
    end

    it 'keeps WHB as default' do
      expect(admin_user.servicio_de_impresion_id).to eq(1)
      expect(admin_user.servicio_de_impresion).to eq(Usuarios::ServicioDeImpresion[:whb])
    end
  end

  describe 'PATCH /cuenta/cambiar_vista_productos' do
    context 'as cliente' do
      before { login_as(cliente_user) }

      it 'updates vista_productos to lista' do
        patch '/cuenta/cambiar_vista_productos', params: { vista: 'lista' }, xhr: true
        expect(response).to have_http_status(:ok)
        expect(cliente_user.reload.vista_productos).to eq 'lista'
      end

      it 'updates vista_productos back to pasadores' do
        cliente_user.update_column(:vista_productos, 'lista')
        patch '/cuenta/cambiar_vista_productos', params: { vista: 'pasadores' }, xhr: true
        expect(response).to have_http_status(:ok)
        expect(cliente_user.reload.vista_productos).to eq 'pasadores'
      end

      it 'rejects invalid vista value' do
        patch '/cuenta/cambiar_vista_productos', params: { vista: 'kanban' }, xhr: true
        expect(response).to have_http_status(:unprocessable_entity)
        expect(cliente_user.reload.vista_productos).to eq 'lista'
      end
    end
  end
end
