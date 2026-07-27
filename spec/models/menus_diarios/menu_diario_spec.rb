require 'rails_helper'

RSpec.describe MenusDiarios::MenuDiario, type: :model do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Menu2') }
  let(:categoria) { Productos::Categoria.create!(nombre: 'Categoria Menu2', tienda: tienda, menu_diario: true) }
  let(:categoria_normal) { Productos::Categoria.create!(nombre: 'Cat Normal', tienda: tienda, menu_diario: false) }
  let(:producto) { Productos::Producto.create!(nombre: 'Producto Menu2', tienda: tienda, categoria: categoria) }
  let(:producto_normal) { Productos::Producto.create!(nombre: 'Producto Normal', tienda: tienda, categoria: categoria_normal) }
  let(:autor) do
    Clientes::Cuenta.create!(nombre: 'cuenta md', cliente: Clientes::Cliente.create!(nombre: 'Cliente nuevo', cuit: '20294834487', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: tienda))
    Usuarios::Usuario.create!(
      nombre: 'Autor Menu3',
      login: 'autor_menu2',
      password: 'password123',
      password_confirmation: 'password123',
      email: 'autor@example.com',
      tipo_usuario_id: 1,
      dni: 12_345_679,
      cuenta: Clientes::Cuenta.last
    )
  end
  let(:menu_diario) { described_class.new(productos: [producto], fecha: Time.zone.today, descripcion: 'Menu del dia2', tienda: tienda, autor: autor) }

  it 'is valid with valid attributes' do
    expect(menu_diario).to be_valid
  end

  it 'requires producto' do
    menu_diario.productos.clear
    expect(menu_diario).not_to be_valid
    expect(menu_diario.errors[:productos]).to be_present
  end

  it 'requires fecha' do
    menu_diario.fecha = nil
    expect(menu_diario).not_to be_valid
    expect(menu_diario.errors[:fecha]).to be_present
  end

  it 'to_s returns descripcion' do
    expect(menu_diario.to_s).to eq 'Producto Menu2: Menu del dia2'
  end

  it 'tienda returns assigned tienda' do
    expect(menu_diario.tienda).to eq tienda
  end

  describe 'tipo enum (ar-enums)' do
    it 'defaults to menu_diario when persisted' do
      menu_diario.save!
      expect(menu_diario.reload.tipo_id).to eq MenusDiarios::Tipo[:menu_diario].id
    end

    it 'allows assignment to productos_diarios via tipo_id' do
      menu_diario.productos = [producto_normal]
      menu_diario.tipo_id = MenusDiarios::Tipo[:productos_diarios].id
      menu_diario.save!
      expect(menu_diario.reload.tipo_id).to eq 2
    end

    it 'exposes scopes for both tipos' do
      menu_diario.save!
      pd = described_class.create!(productos: [producto_normal], fecha: Time.zone.today, descripcion: 'Op del dia',
                                   tienda: tienda, autor: autor, tipo_id: MenusDiarios::Tipo[:productos_diarios].id)

      expect(described_class.menu_diario).to include(menu_diario)
      expect(described_class.menu_diario).not_to include(pd)
      expect(described_class.productos_diarios).to include(pd)
      expect(described_class.productos_diarios).not_to include(menu_diario)
    end
  end

  describe 'menus_unicos validator' do
    it 'allows the same producto (of a non-menu_diario categoria) across tipos for the same fecha' do
      pd_a = described_class.create!(productos: [producto_normal], fecha: Time.zone.today, descripcion: 'PD A',
                                     tienda: tienda, autor: autor, tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
      duplicate = described_class.new(productos: [producto_normal], fecha: pd_a.fecha,
                                      descripcion: 'PD B', tienda: tienda, autor: autor,
                                      tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
      # Same tipo + same producto + same fecha → blocked.
      expect(duplicate).not_to be_valid
    end

    it 'rejects duplicates within the same tipo on the same fecha' do
      menu_diario.save!
      duplicate = described_class.new(productos: [producto], fecha: menu_diario.fecha,
                                      descripcion: 'Otro', tienda: tienda, autor: autor)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:base]).to be_present
    end
  end

  describe 'productos_acordes_al_tipo validator' do
    it 'rejects a menu_diario menu containing a non-menu_diario producto' do
      menu_diario.productos = [producto_normal]
      expect(menu_diario).not_to be_valid
      expect(menu_diario.errors[:productos].join).to include('Menú del día')
    end

    it 'rejects a productos_diarios menu containing a menu_diario producto' do
      pd = described_class.new(productos: [producto], fecha: Time.zone.today, descripcion: 'PD',
                               tienda: tienda, autor: autor,
                               tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
      expect(pd).not_to be_valid
      expect(pd.errors[:productos].join).to include('no pueden ser')
    end

    it 'allows a productos_diarios menu with a non-menu_diario producto' do
      pd = described_class.new(productos: [producto_normal], fecha: Time.zone.today, descripcion: 'PD',
                               tienda: tienda, autor: autor,
                               tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
      expect(pd).to be_valid
    end
  end
end
