require 'rails_helper'

# Step 9 follow-up: when an admin tries to create a cliente, the new-form
# CUIT input pings `lookup_by_cuit` to detect existing rows system-wide. If a
# cliente with that CUIT already exists in another tienda, the admin can
# `vincular_tienda` instead of creating a duplicate.
RSpec.describe 'ClientesController CUIT lookup + vincular', type: :request do
  let(:tienda_a) { create(:tienda, dominio: 'a.example.com') }
  let(:tienda_b) { create(:tienda, dominio: 'b.example.com') }

  let(:admin) do
    user = create(:usuario, visualizando_tienda: tienda_a)
    user.tiendas << tienda_a unless user.tiendas.include?(tienda_a)
    user
  end

  before do
    login_as(admin)
    bypass_authorization
  end

  describe 'GET /clientes/lookup_by_cuit' do
    it 'returns exists:false when no cliente has the cuit' do
      get '/clientes/lookup_by_cuit', params: { cuit: '20294834487' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('exists' => false)
    end

    it 'returns exists:false for malformed cuit (less than 11 digits)' do
      get '/clientes/lookup_by_cuit', params: { cuit: '123' }

      expect(response.parsed_body).to include('exists' => false)
    end

    it 'finds an existing cliente regardless of which tienda it belongs to' do
      cliente = create(:cliente, nombre: 'Sancor Salud', cuit: '20294834487', tiendas: [tienda_b])

      get '/clientes/lookup_by_cuit', params: { cuit: '20-29483448-7' }

      body = response.parsed_body
      expect(body).to include(
        'exists' => true,
        'id' => cliente.id,
        'nombre' => 'Sancor Salud',
        'ya_vinculado' => false,
        'tiendas' => [tienda_b.nombre]
      )
      expect(body['vincular_url']).to include("/clientes/#{cliente.id}/vincular_tienda")
    end

    it 'returns ya_vinculado:true when cliente already lives in current tienda' do
      cliente = create(:cliente, nombre: 'Acme', cuit: '20294834487', tiendas: [tienda_a])

      get '/clientes/lookup_by_cuit', params: { cuit: '20294834487' }

      body = response.parsed_body
      expect(body).to include('exists' => true, 'id' => cliente.id, 'ya_vinculado' => true)
    end
  end

  describe 'POST /clientes/:id/vincular_tienda' do
    let!(:cliente) { create(:cliente, nombre: 'Sancor Salud', cuit: '20294834487', tiendas: [tienda_b]) }

    it 'adds tienda_activa to the cliente HABTM and redirects to edit' do
      post "/clientes/#{cliente.id}/vincular_tienda"

      expect(cliente.reload.tiendas).to contain_exactly(tienda_a, tienda_b)
      expect(response).to redirect_to(edit_cliente_path(cliente))
      expect(flash[:notice]).to match(/vinculado a/i)
    end

    it 'is idempotent when cliente is already in current tienda' do
      cliente.tiendas << tienda_a

      post "/clientes/#{cliente.id}/vincular_tienda"

      expect(cliente.reload.tiendas).to contain_exactly(tienda_a, tienda_b)
      expect(response).to redirect_to(edit_cliente_path(cliente))
    end
  end
end
