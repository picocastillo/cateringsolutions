require 'rails_helper'

RSpec.describe Usuarios::Usuario, type: :model do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Test') }
  let(:cliente) { Clientes::Cliente.create!(nombre: 'Cliente Test', cuit: '20294834487', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: tienda) }
  let(:cuenta) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Cuenta Test') }
  let(:usuario) do
    described_class.new(
      nombre: 'Test User',
      login: 'testuser',
      password: 'password123',
      password_confirmation: 'password123',
      email: 'test@example.com',
      tipo_usuario_id: 1,
      dni: 12_345_678,
      cuenta: cuenta
    )
  end

  it 'is valid with valid attributes' do
    expect(usuario).to be_valid
  end

  it 'requires nombre' do
    usuario.nombre = nil
    expect(usuario).not_to be_valid
    expect(usuario.errors[:nombre]).to be_present
  end

  it 'requires login' do
    usuario.login = nil
    expect(usuario).not_to be_valid
    expect(usuario.errors[:login]).to be_present
  end

  it 'requires password confirmation to match' do
    usuario.password_confirmation = 'wrong'
    expect(usuario).not_to be_valid
    expect(usuario.errors[:password_confirmation]).to be_present
  end

  it 'requires email to have a valid format' do
    usuario.email = 'invalid_email'
    expect(usuario).not_to be_valid
    expect(usuario.errors[:email]).to be_present

    usuario.email = 'valid@email.com'
    expect(usuario).to be_valid
  end

  it 'requires dni for clientes' do
    usuario.dni = nil
    expect(usuario).not_to be_valid
    expect(usuario.errors[:dni]).to be_present
  end

  it 'authenticates with correct password' do
    usuario.save!
    expect(usuario.authenticated?('password123')).to be true
  end

  it 'does not authenticate with wrong password' do
    usuario.save!
    expect(usuario.authenticated?('wrongpass')).to be false
  end

  it 'assigns tienda_cliente for cliente' do
    usuario.save!
    expect(usuario.tienda_cliente).to eq tienda
  end

  it 'returns false for admin? if not admin' do
    expect(usuario.admin?).to be false
  end

  it 'returns true for cliente? if tipo_usuario_id is 1' do
    usuario.tipo_usuario_id = 1
    expect(usuario.cliente?).to be true
  end

  it 'returns false for cliente? if tipo_usuario_id is not 1' do
    usuario.tipo_usuario_id = 2
    expect(usuario.cliente?).to be false
  end

  it 'requires unique login' do
    usuario.save!
    usuario2 = usuario.dup
    expect(usuario2).not_to be_valid
    expect(usuario2.errors[:login]).to be_present
  end

  it 'returns nombre_y_cliente' do
    expect(usuario.nombre_y_cliente).to include(usuario.nombre)
    expect(usuario.nombre_y_cliente).to include(usuario.cuenta.cliente.nombre)
  end

  it 'returns nombre_normalizado' do
    usuario.nombre = 'jUAN perez'
    expect(usuario.nombre_normalizado).to eq 'Juan Perez'
  end

  it 'returns to_s' do
    expect(usuario.to_s).to include(usuario.nombre)
  end

  it 'returns false for operador? if admin' do
    allow(usuario).to receive(:admin?).and_return(true)
    expect(usuario.operador?).to be false
  end

  it 'returns true for operador? if not admin and no cuenta' do
    usuario.cuenta = nil
    allow(usuario).to receive(:admin?).and_return(false)
    expect(usuario.operador?).to be true
  end

  it 'returns false for robot? if not robot' do
    expect(usuario.robot?).to be false
  end

  it 'returns false for super_admin? if id != 1' do
    usuario.id = 2
    expect(usuario.super_admin?).to be false
  end

  it 'returns true for super_admin? if id == 1' do
    usuario.id = 1
    expect(usuario.super_admin?).to be true
  end

  it 'returns false for cumple_rol? if no roles' do
    expect(usuario.cumple_rol?(:admin)).to be false
  end

  it 'returns false for cumple_roles? if no roles' do
    expect(usuario.cumple_roles?(:admin, :comprador)).to be false
  end

  it 'returns false for cumple_algun_rol? if no roles' do
    expect(usuario.cumple_algun_rol?(:admin, :comprador)).to be false
  end

  it 'returns false for accede_a_modulo? if no roles' do
    expect(usuario.accede_a_modulo?(:Usuarios)).to be false
  end

  it 'returns false for password_expired? if password_expires_at is in future' do
    usuario.password_expires_at = 1.day.from_now
    expect(usuario.password_expired?).to be false
  end

  it 'returns true for password_expired? if password_expires_at is in past' do
    usuario.password_expires_at = 1.day.ago
    expect(usuario.password_expired?).to be true
  end

  it "returns false for sistema? if login is not 'sistema'" do
    expect(usuario.sistema?).to be false
  end

  it "returns true for sistema? if login is 'sistema'" do
    usuario.login = 'sistema'
    expect(usuario.sistema?).to be true
  end

  it 'returns email_principal' do
    usuario.email = 'a@b.com, c@d.com'
    expect(usuario.email_principal).to eq 'a@b.com'
  end

  describe 'dni length validation' do
    it 'does not require dni length for non-client users' do
      operador = described_class.new(
        nombre: 'Operador',
        login: 'operador_test',
        password: 'password123',
        password_confirmation: 'password123',
        email: 'op@example.com',
        tipo_usuario_id: 2,
        cuenta: nil,
        visualizando_tienda: tienda
      )
      operador.valid?
      expect(operador.errors[:dni]).to be_empty
    end
  end

  describe '#asignar_tienda' do
    it 'auto-assigns tienda_cliente_id for client users with cuenta' do
      usuario.tienda_cliente = nil
      usuario.valid?
      expect(usuario.tienda_cliente).to eq tienda
      expect(usuario.errors[:tienda_cliente_id]).to be_empty
    end

    it 'does not show tienda_cliente_id error for non-client users' do
      operador = described_class.new(
        nombre: 'Operador',
        login: 'operador_test2',
        password: 'password123',
        password_confirmation: 'password123',
        email: 'op2@example.com',
        tipo_usuario_id: 2,
        cuenta: nil,
        visualizando_tienda: tienda
      )
      operador.valid?
      expect(operador.errors[:tienda_cliente_id]).to be_empty
    end
  end

  describe 'dni uniqueness scoped to tienda' do
    before { usuario.save! }

    it 'rejects duplicate dni in the same tienda' do
      usuario2 = described_class.new(
        nombre: 'Other User',
        login: 'otheruser',
        password: 'password123',
        password_confirmation: 'password123',
        email: 'other@example.com',
        tipo_usuario_id: 1,
        dni: usuario.dni,
        cuenta: cuenta
      )
      expect(usuario2).not_to be_valid
      expect(usuario2.errors[:dni]).to be_present
    end

    it 'does not allow same dni in any tienda (globally unique)' do
      otra_tienda = Tiendas::Tienda.create!(nombre: 'Otra Tienda')
      otro_cliente = Clientes::Cliente.create!(nombre: 'Otro Cliente', cuit: '20111111112', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: otra_tienda)
      otra_cuenta = Clientes::Cuenta.create!(cliente: otro_cliente, nombre: 'Otra Cuenta')

      usuario2 = described_class.new(
        nombre: 'Other User',
        login: 'otheruser',
        password: 'password123',
        password_confirmation: 'password123',
        email: 'other@example.com',
        tipo_usuario_id: 1,
        dni: usuario.dni,
        cuenta: otra_cuenta
      )
      expect(usuario2).not_to be_valid
      expect(usuario2.errors[:dni]).to be_present
    end
  end

  describe '#validar_local' do
    context 'when non-client user has no visualizando_tienda' do
      let(:usuario_sin_tienda) do
        described_class.new(
          nombre: 'Admin User',
          login: 'adminuser',
          password: 'password123',
          password_confirmation: 'password123',
          email: 'admin@example.com',
          tipo_usuario_id: 2,
          cuenta: nil,
          visualizando_tienda: nil,
          local: nil
        )
      end

      it 'does not raise NoMethodError' do
        expect { usuario_sin_tienda.valid? }.not_to raise_error
      end
    end

    context 'when non-client user has tienda with multiple_locales and no local' do
      let(:tienda_multi) { Tiendas::Tienda.create!(nombre: 'Tienda Multi', multiple_locales: true) }
      let(:usuario_sin_local) do
        described_class.new(
          nombre: 'Operator User',
          login: 'operatoruser',
          password: 'password123',
          password_confirmation: 'password123',
          email: 'op@example.com',
          tipo_usuario_id: 2,
          cuenta: nil,
          visualizando_tienda: tienda_multi,
          local: nil
        )
      end

      it 'adds an error on local' do
        usuario_sin_local.valid?
        expect(usuario_sin_local.errors[:local]).to be_present
      end
    end

    context 'when non-client user has tienda without multiple_locales and no local' do
      let(:tienda_single) { Tiendas::Tienda.create!(nombre: 'Tienda Single', multiple_locales: false) }
      let(:usuario_sin_local) do
        described_class.new(
          nombre: 'Operator User',
          login: 'operatoruser2',
          password: 'password123',
          password_confirmation: 'password123',
          email: 'op2@example.com',
          tipo_usuario_id: 2,
          cuenta: nil,
          visualizando_tienda: tienda_single,
          local: nil
        )
      end

      it 'does not add an error on local' do
        usuario_sin_local.valid?
        expect(usuario_sin_local.errors[:local]).to be_empty
      end
    end
  end

  describe 'tipo_usuario_id presence validation' do
    let(:tienda) { create(:tienda) }

    it 'is invalid when tipo_usuario_id is missing on a new record' do
      usuario = described_class.new(
        nombre: 'Sin Tipo', login: 'sintipo_user', email: 'sintipo@example.com',
        password: 'password123', password_confirmation: 'password123',
        visualizando_tienda: tienda
      )

      expect(usuario.valid?).to be false
      expect(usuario.errors[:tipo_usuario_id]).to be_present
    end

    it 'reports tipo_usuario_id error alongside other errors (no early-return masking)' do
      # Reproduces the bug: form posted with no tipo selected and no nombre →
      # user used to only see "Tienda cliente no puede estar en blanco". They
      # should also see the missing tipo error.
      cuenta = create(:cuenta)
      usuario = described_class.new(cuenta: cuenta, login: 'orphan_user', email: 'o@example.com',
                                    password: 'password123', password_confirmation: 'password123')
      usuario.valid?

      expect(usuario.errors[:tipo_usuario_id]).to be_present
      expect(usuario.errors[:tienda_cliente_id]).to be_present
      expect(usuario.errors[:nombre]).to be_present
    end

    it 'is valid for cliente (tipo 1) with a cuenta' do
      cuenta = create(:cuenta)
      usuario = described_class.new(
        nombre: 'Cli', login: 'cli_user', email: 'cli@example.com',
        password: 'password123', password_confirmation: 'password123',
        tipo_usuario_id: 1, cuenta: cuenta, dni: 12_345_678,
        tienda_cliente: cuenta.cliente.tienda, visualizando_tienda: cuenta.cliente.tienda
      )
      usuario.valid?

      expect(usuario.errors[:tipo_usuario_id]).to be_empty
    end

    it 'is valid for admin (tipo 2)' do
      usuario = described_class.new(
        nombre: 'Adm', login: 'adm_user', email: 'a@example.com',
        password: 'password123', password_confirmation: 'password123',
        tipo_usuario_id: 2, visualizando_tienda: tienda
      )
      usuario.valid?

      expect(usuario.errors[:tipo_usuario_id]).to be_empty
    end
  end

  describe 'vista_productos' do
    it 'defaults to lista for new records' do
      expect(described_class.new.vista_productos).to eq 'lista'
    end

    it 'allows pasadores and lista' do
      usuario.vista_productos = 'lista'
      expect(usuario).to be_valid
      usuario.vista_productos = 'pasadores'
      expect(usuario).to be_valid
    end

    it 'rejects unknown vista values' do
      usuario.vista_productos = 'kanban'
      expect(usuario).not_to be_valid
      expect(usuario.errors[:vista_productos]).to be_present
    end

    describe '#vista_lista?' do
      it 'returns true when vista_productos is lista' do
        usuario.vista_productos = 'lista'
        expect(usuario.vista_lista?).to be true
      end

      it 'returns false when vista_productos is pasadores' do
        usuario.vista_productos = 'pasadores'
        expect(usuario.vista_lista?).to be false
      end
    end
  end
end
