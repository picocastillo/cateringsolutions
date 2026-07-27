require 'rails_helper'

RSpec.describe Usuarios::RolAsignado, type: :model do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Test rol asignado') }
  let(:cliente) { Clientes::Cliente.create!(nombre: 'Cliente Test rol asignado', cuit: '20294834487', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: tienda) }
  let(:cuenta) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Cuenta Test rol asignado') }
  let(:usuario) do
    Usuarios::Usuario.create!(
      nombre: 'Test User rol asignado',
      login: 'testuser2',
      password: 'password123',
      password_confirmation: 'password123',
      email: 'test2@example.com',
      tipo_usuario_id: 1,
      dni: 87_654_321,
      cuenta: cuenta
    )
  end
  let(:rol) { Usuarios::Rol.create!(nombre: 'admin', titulo: 'Administrador', modulo: 'Usuarios') }
  let(:rol_asignado) { described_class.new(usuario: usuario, rol: rol) }

  it 'is valid' do
    expect(rol_asignado).to be_valid
  end

  it 'belongs to usuario' do
    expect(rol_asignado.usuario).to eq usuario
  end

  it 'belongs to rol' do
    expect(rol_asignado.rol).to eq rol
  end
end
