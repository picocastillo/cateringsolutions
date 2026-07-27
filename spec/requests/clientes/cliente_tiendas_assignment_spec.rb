require 'rails_helper'

# Step 6 of shared-clientes migration: super_admin must be able to assign a
# cliente to multiple tiendas through the cliente edit form. The form posts
# `cliente[tienda_ids][]`, which the controller permits and assigns to the
# HABTM `clientes_tiendas` join.
RSpec.describe 'ClientesController cliente.tienda_ids assignment', type: :request do
  let(:tienda_a) { create(:tienda, dominio: 'a.example.com') }
  let(:tienda_b) { create(:tienda, dominio: 'b.example.com') }
  let(:tienda_c) { create(:tienda, dominio: 'c.example.com') }

  let(:super_admin) do
    user = create(:usuario, visualizando_tienda: tienda_a)
    user.tiendas << tienda_a unless user.tiendas.include?(tienda_a)
    allow_any_instance_of(Usuarios::Usuario).to receive(:super_admin?).and_return(true)
    user
  end

  let!(:cliente) { create(:cliente, tienda: tienda_a) }

  before do
    login_as(super_admin)
    bypass_authorization
  end

  it 'persists tienda_ids through the cliente update form' do
    put "/clientes/#{cliente.id}", params: { cliente: { nombre: cliente.nombre, tienda_ids: [tienda_a.id, tienda_b.id] } }

    expect(cliente.reload.tiendas).to contain_exactly(tienda_a, tienda_b)
  end

  it 'replaces the set on subsequent updates' do
    cliente.tiendas << tienda_b

    put "/clientes/#{cliente.id}", params: { cliente: { nombre: cliente.nombre, tienda_ids: [tienda_a.id, tienda_c.id] } }

    expect(cliente.reload.tiendas).to contain_exactly(tienda_a, tienda_c)
  end

  it 'removes all extra tiendas when only the primary is selected' do
    cliente.tiendas << tienda_b
    cliente.tiendas << tienda_c

    put "/clientes/#{cliente.id}", params: { cliente: { nombre: cliente.nombre, tienda_ids: [tienda_a.id] } }

    expect(cliente.reload.tiendas).to contain_exactly(tienda_a)
  end
end
