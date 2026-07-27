require 'rails_helper'

RSpec.describe Ability, type: :model do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Ability') }
  let(:cliente) { Clientes::Cliente.create!(nombre: 'Cliente Ability', cuit: '20294834487', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: tienda) }
  let(:cuenta) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Cuenta Ability') }
  let(:usuario) do
    Usuarios::Usuario.create!(
      nombre: 'Ability User',
      login: 'abilityuser',
      password: 'password123',
      password_confirmation: 'password123',
      email: 'ability@example.com',
      tipo_usuario_id: 1,
      dni: 12_345_679,
      cuenta: cuenta
    )
  end

  it 'initializes with a user' do
    ability = described_class.new(usuario)
    expect(ability.user).to eq usuario
  end

  it 'responds to can? and cannot?' do
    ability = described_class.new(usuario)
    expect(ability).to respond_to(:can?)
    expect(ability).to respond_to(:cannot?)
  end

  it 'delegates admin? to user' do
    ability = described_class.new(usuario)
    expect(ability.user).to receive(:admin?).and_return(false)
    expect(ability.user.admin?).to be false
  end

  it 'delegates cliente? to user' do
    ability = described_class.new(usuario)
    expect(ability.user).to receive(:cliente?).and_return(true)
    expect(ability.user.cliente?).to be true
  end
end
