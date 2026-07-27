require 'rails_helper'

RSpec.describe Pedidos::PedidoMultiple, type: :model do
  subject(:grupo) { described_class.create!(usuario: usuario) }

  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Multi', maneja_stock: false) }
  let(:cliente) do
    Clientes::Cliente.create!(
      nombre: 'Cliente Multi', cuit: '20294834487',
      dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1,
      horario_corte_pedidos: '23:00', tienda: tienda
    )
  end
  let(:cuenta) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Cuenta Multi') }
  let(:usuario) do
    Usuarios::Usuario.create!(
      nombre: 'Usuario Multi', login: 'usuariomulti',
      password: 'password123', password_confirmation: 'password123',
      email: 'multi@example.com', tipo_usuario_id: 1, dni: 99_000_001,
      cuenta: cuenta, tienda_cliente: tienda
    )
  end

  describe 'associations' do
    it { is_expected.to respond_to(:pedidos) }
    it { is_expected.to respond_to(:pagos_electronicos) }
    it { is_expected.to belong_to(:usuario).optional }
    it { is_expected.to belong_to(:cuenta).optional }
  end

  describe 'validations' do
    it 'is valid with only a usuario' do
      expect(described_class.new(usuario: usuario)).to be_valid
    end

    it 'is valid with only a cuenta' do
      expect(described_class.new(cuenta: cuenta)).to be_valid
    end

    it 'is invalid without usuario or cuenta' do
      grupo = described_class.new
      expect(grupo).not_to be_valid
      expect(grupo.errors[:base]).to include('Debe tener un usuario o una cuenta')
    end
  end

  describe 'enums' do
    it 'defaults to abierto' do
      expect(grupo).to be_abierto
    end

    it 'can transition to pagando' do
      grupo.pagando!
      expect(grupo).to be_pagando
    end

    it 'can transition to pagado' do
      grupo.pagado!
      expect(grupo).to be_pagado
    end
  end

  describe '#total' do
    it 'sums importe_total of all pedidos' do
      # Without real pedidos with products, total is 0
      expect(grupo.total).to eq(0)
    end
  end

  describe '#single?' do
    it 'is true with zero pedidos' do
      expect(grupo.single?).to be(true)
    end

    it 'is false with two pedidos' do
      2.times do
        Pedidos::Pedido.create!(
          tienda: tienda, autor: usuario, usuario: usuario,
          cuenta: cuenta, estado_id: 1, pedido_multiple_id: grupo.id
        )
      end
      grupo.reload
      expect(grupo.single?).to be(false)
    end
  end

  describe '#external_reference' do
    it 'returns the expected format' do
      expect(grupo.external_reference(usuario.id)).to eq("multiple-#{grupo.id}-#{usuario.id}")
    end
  end

  describe 'cross-user contamination guard' do
    let(:otro_usuario) do
      Usuarios::Usuario.create!(
        nombre: 'Otro', login: 'otromulti',
        password: 'password123', password_confirmation: 'password123',
        email: 'otro@example.com', tipo_usuario_id: 1, dni: 99_000_002,
        cuenta: cuenta, tienda_cliente: tienda
      )
    end

    it 'rejects saving the group when a pedido belongs to a different user' do
      pedido_propio = Pedidos::Pedido.create!(
        tienda: tienda, autor: usuario, usuario: usuario,
        cuenta: cuenta, estado_id: 1, pedido_multiple_id: grupo.id
      )
      pedido_ajeno = Pedidos::Pedido.create!(
        tienda: tienda, autor: otro_usuario, usuario: otro_usuario,
        cuenta: cuenta, estado_id: 1
      )
      pedido_ajeno.update_column(:pedido_multiple_id, grupo.id)
      grupo.reload
      expect(grupo).not_to be_valid
      expect(grupo.errors[:base].join).to match(/no pertenece al due\u00f1o/)
      expect(pedido_propio).to be_persisted
    end

    it 'allows the admin (autor) to add pedidos for other usuarios in the same cuenta' do
      Pedidos::Pedido.create!(
        tienda: tienda, autor: usuario, usuario: otro_usuario,
        cuenta: cuenta, estado_id: 1, pedido_multiple_id: grupo.id
      )
      grupo.reload
      expect(grupo).to be_valid
    end

    it 'allows cuenta-only groups to mix usuarios as long as the cuenta matches' do
      bucket = described_class.create!(cuenta: cuenta)
      Pedidos::Pedido.create!(
        tienda: tienda, autor: usuario, usuario: usuario,
        cuenta: cuenta, estado_id: 1, pedido_multiple_id: bucket.id
      )
      Pedidos::Pedido.create!(
        tienda: tienda, autor: otro_usuario, usuario: otro_usuario,
        cuenta: cuenta, estado_id: 1, pedido_multiple_id: bucket.id
      )
      bucket.reload
      expect(bucket).to be_valid
    end
  end
end
