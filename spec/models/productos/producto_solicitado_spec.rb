require 'rails_helper'

RSpec.describe Productos::ProductoSolicitado, type: :model do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda ProductoSolicitado') }
  let(:categoria) { Productos::Categoria.create!(nombre: 'Categoria PS', tienda: tienda) }
  let(:producto) { Productos::Producto.create!(nombre: 'Producto PS', tienda: tienda, categoria: categoria) }
  let(:cliente) { Clientes::Cliente.create!(nombre: 'Cliente PS', cuit: '20294834487', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: tienda) }
  let(:cuenta) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Cuenta PS') }
  let(:usuario) do
    Usuarios::Usuario.create!(
      nombre: 'Usuario PS',
      login: 'usuariops',
      password: 'password123',
      password_confirmation: 'password123',
      email: 'ps@example.com',
      tipo_usuario_id: 1,
      dni: 12_345_678,
      cuenta: cuenta
    )
  end
  let(:valid_fecha) do
    # Set to the next available weekday (not Saturday or Sunday)
    d = Time.zone.today + 1
    d += 1 while d.saturday? || d.sunday?
    d
  end
  let(:pedido) do
    Pedidos::Pedido.create!(
      usuario: usuario,
      autor: usuario,
      cuenta: cuenta,
      fecha: valid_fecha,
      estado_id: 1,
      tienda: tienda
    )
  end
  let(:producto_solicitado) do
    described_class.new(
      pedido: pedido,
      producto: producto,
      cantidad: 2,
      precio_unitario: 10.5
    )
  end
  let!(:precio) do
    Productos::Precio.create!(producto: producto, importe: 10.5, fecha_desde: Time.zone.today - 1)
  end

  it 'is valid with valid attributes' do
    expect(producto_solicitado).to be_valid
  end

  it 'requires pedido' do
    producto_solicitado.pedido = nil
    # Avoid calling asignar_precio logic that expects pedido to be present
    allow(producto_solicitado).to receive(:asignar_precio)
    expect(producto_solicitado).not_to be_valid
    expect(producto_solicitado.errors[:pedido]).to be_present
  end

  it 'requires producto' do
    producto_solicitado.producto = nil
    # Avoid calling asignar_precio logic that expects producto to be present
    allow(producto_solicitado).to receive(:asignar_precio)
    expect(producto_solicitado).not_to be_valid
    expect(producto_solicitado.errors[:producto]).to be_present
  end

  it 'requires cantidad' do
    producto_solicitado.cantidad = nil
    expect(producto_solicitado).not_to be_valid
    expect(producto_solicitado.errors[:cantidad]).to be_present
  end

  it 'requires precio_unitario' do
    producto_solicitado.precio_unitario = nil
    # Avoid calling asignar_precio logic that may set precio_unitario
    allow(producto_solicitado).to receive(:asignar_precio)
    expect(producto_solicitado).not_to be_valid
    expect(producto_solicitado.errors[:precio_unitario]).to be_present
  end

  it 'to_s returns a string' do
    expect(producto_solicitado.to_s).to be_a(String)
  end

  it 'realizado is false by default' do
    expect(producto_solicitado.realizado).to be false
  end

  it 'can set realizado to true' do
    producto_solicitado.realizado = true
    expect(producto_solicitado.realizado).to be true
  end

  it 'returns correct pedido' do
    expect(producto_solicitado.pedido).to eq pedido
  end

  it 'returns correct producto' do
    expect(producto_solicitado.producto).to eq producto
  end

  it 'returns correct cantidad' do
    expect(producto_solicitado.cantidad).to eq 2
  end

  it 'returns correct precio_unitario' do
    expect(producto_solicitado.precio_unitario).to eq 10.5
  end

  describe '#importe_total' do
    it 'calculates total from cantidad and precio_unitario' do
      producto_solicitado.cantidad = 3
      producto_solicitado.precio_unitario = 50
      expect(producto_solicitado.importe_total.to_f).to eq(150.0)
    end

    it 'returns zero when cantidad is zero' do
      producto_solicitado.cantidad = 0
      producto_solicitado.precio_unitario = 50
      expect(producto_solicitado.importe_total.to_f).to eq(0)
    end
  end

  describe '#precio_por_unidad' do
    it 'returns unit price as Money' do
      producto_solicitado.precio_unitario = 75
      result = producto_solicitado.precio_por_unidad
      expect(result).to be_a(Danconia::Money)
      expect(result.to_f).to eq(75.0)
    end
  end

  describe '#nombre_carrito' do
    it 'returns producto name when no menu_diario' do
      producto_solicitado.menu_diario = nil
      expect(producto_solicitado.nombre_carrito).to include(producto.nombre)
    end

    it 'returns string representation' do
      producto_solicitado.cantidad = 3
      result = producto_solicitado.nombre_carrito
      expect(result).to be_a(String)
    end
  end

  describe '#sin_importes' do
    it 'returns cantidad and nombre when cantidad is positive' do
      producto_solicitado.cantidad = 3
      result = producto_solicitado.sin_importes
      expect(result).to include('3')
      expect(result).to include(producto.nombre)
    end
  end

  describe '#sin_producto' do
    it 'returns formatted cantidad and price' do
      producto_solicitado.cantidad = 2
      producto_solicitado.precio_unitario = 50
      result = producto_solicitado.sin_producto
      expect(result).to be_a(String)
      expect(result).to include('2')
    end
  end

  describe '#codigo_de_barras' do
    it 'returns string with producto codigo' do
      producto.update(codigo: 'PROD-123')
      expect(producto_solicitado.codigo_de_barras).to include('PROD-123')
    end

    it 'handles nil codigo gracefully' do
      pedido.codigo = nil
      producto.update(codigo: nil)
      expect(producto_solicitado.codigo_de_barras).to eq('-')
    end
  end

  describe '#actualizar_precio' do
    it 'updates precio_unitario from producto precio' do
      Productos::Precio.create!(producto: producto, importe: 25, fecha_desde: Time.zone.today - 1)
      producto_solicitado.precio_unitario = 0
      producto_solicitado.actualizar_precio
      expect(producto_solicitado.precio_unitario).to eq(25)
    end

    it 'adds error when no precio found' do
      Productos::Precio.delete_all
      producto_solicitado.actualizar_precio
      expect(producto_solicitado.errors[:precio_unitario]).to be_present
    end

    context 'when categoria.menu_diario is true' do
      let(:categoria_md) do
        Productos::Categoria.create!(nombre: 'MD Cat', tienda: tienda, menu_diario: true)
      end
      let(:producto_md) do
        Productos::Producto.create!(nombre: 'Producto MD', tienda: tienda, categoria: categoria_md)
      end
      let(:autor) { usuario }

      before do
        Productos::Precio.create!(producto: producto_md, importe: 50, fecha_desde: Time.zone.today - 1)
      end

      it 'auto-links to a menu_diario tipo MenuDiario for that fecha but ignores productos_diarios tipo' do
        clasico = MenusDiarios::MenuDiario.create!(productos: [producto_md], fecha: pedido.fecha,
                                                   descripcion: 'Clasico', tienda: tienda, autor: autor,
                                                   tipo_id: MenusDiarios::Tipo[:menu_diario].id)
        # A productos_diarios menu containing the same producto on the same date
        # MUST NOT be picked up — it would attach the wrong context to the
        # ProductoSolicitado. (productos_diarios menus contain non-md categorias
        # so we wire it via raw SQL to bypass the categoria validator.)
        pd = MenusDiarios::MenuDiario.new(fecha: pedido.fecha, descripcion: 'PD', tienda: tienda,
                                          autor: autor, tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
        pd.productos << producto_md
        pd.save(validate: false)

        ps = described_class.new(pedido: pedido, producto: producto_md, cantidad: 1, precio_unitario: 0)
        ps.actualizar_precio
        expect(ps.menu_diario_id).to eq(clasico.id)
      end

      it 'does NOT link when only a productos_diarios MenuDiario exists for that fecha' do
        pd = MenusDiarios::MenuDiario.new(fecha: pedido.fecha, descripcion: 'PD', tienda: tienda,
                                          autor: autor, tipo_id: MenusDiarios::Tipo[:productos_diarios].id)
        pd.productos << producto_md
        pd.save(validate: false)

        ps = described_class.new(pedido: pedido, producto: producto_md, cantidad: 1, precio_unitario: 0)
        ps.actualizar_precio
        expect(ps.menu_diario_id).to be_nil
      end
    end
  end

  describe 'peso (weight-based products)' do
    let(:pesable_ps) do
      described_class.new(
        pedido: pedido,
        producto: producto,
        cantidad: 1,
        precio_unitario: 500,
        peso: 1.250
      )
    end

    describe 'validation' do
      it 'allows nil peso' do
        producto_solicitado.peso = nil
        expect(producto_solicitado).to be_valid
      end

      it 'allows positive peso' do
        producto_solicitado.peso = 0.5
        expect(producto_solicitado).to be_valid
      end

      it 'rejects zero peso' do
        producto_solicitado.peso = 0
        expect(producto_solicitado).not_to be_valid
        expect(producto_solicitado.errors[:peso]).to be_present
      end

      it 'rejects negative peso' do
        producto_solicitado.peso = -1
        expect(producto_solicitado).not_to be_valid
        expect(producto_solicitado.errors[:peso]).to be_present
      end
    end

    describe '#importe_total' do
      it 'calculates peso * precio when peso present (cantidad always 1)' do
        # 1 * 1.250 * 500 = 625
        expect(pesable_ps.importe_total.to_f).to eq(625.0)
      end

      it 'calculates cantidad * precio when peso nil' do
        producto_solicitado.cantidad = 3
        producto_solicitado.precio_unitario = 50
        producto_solicitado.peso = nil
        expect(producto_solicitado.importe_total.to_f).to eq(150.0)
      end

      it 'handles fractional peso correctly' do
        pesable_ps.peso = 0.333
        pesable_ps.cantidad = 1
        pesable_ps.precio_unitario = 1000
        # 1 * 0.333 * 1000 = 333
        expect(pesable_ps.importe_total.to_f).to eq(333.0)
      end
    end

    describe '#importe_total_sin_descuento' do
      it 'calculates peso * precio_unitario when peso present (cantidad always 1)' do
        # 1 * 1.250 * 500 = 625
        expect(pesable_ps.importe_total_sin_descuento.to_f).to eq(625.0)
      end

      it 'calculates cantidad * precio_unitario when peso nil' do
        producto_solicitado.cantidad = 3
        producto_solicitado.precio_unitario = 50
        producto_solicitado.peso = nil
        expect(producto_solicitado.importe_total_sin_descuento.to_f).to eq(150.0)
      end
    end

    describe '#peso_total' do
      it 'returns peso when peso present (cantidad always 1)' do
        expect(pesable_ps.peso_total).to eq(1.25) # 1 * 1.250
      end

      it 'returns nil when peso nil' do
        producto_solicitado.peso = nil
        expect(producto_solicitado.peso_total).to be_nil
      end
    end

    describe '#to_s' do
      it 'includes Kg format when peso present' do
        result = pesable_ps.to_s
        expect(result).to include('Kg')
        expect(result).to include('1.25')
      end

      it 'does not include cantidad prefix for pesable' do
        result = pesable_ps.to_s
        expect(result).not_to include('1 x')
      end

      it 'includes Un. format when peso nil' do
        producto_solicitado.peso = nil
        result = producto_solicitado.to_s
        expect(result).to include('Un.')
      end
    end

    describe '#sin_importes' do
      it 'includes Kg when peso present' do
        result = pesable_ps.sin_importes
        expect(result).to include('Kg')
      end

      it 'does not include Kg when peso nil' do
        producto_solicitado.peso = nil
        result = producto_solicitado.sin_importes
        expect(result).not_to include('Kg')
      end
    end

    describe '#sin_producto' do
      it 'includes Kg when peso present' do
        result = pesable_ps.sin_producto
        expect(result).to include('Kg')
      end

      it 'does not include Kg when peso nil' do
        producto_solicitado.peso = nil
        result = producto_solicitado.sin_producto
        expect(result).not_to include('Kg')
      end
    end
  end

  describe 'calculated fields' do
    it 'responds to common methods' do
      expect(producto_solicitado).to respond_to(:to_s)
      expect(producto_solicitado).to respond_to(:importe_total)
    end
  end

  # Bug B: callback / writes on confirmed pedidos must NOT mutate ps state.
  # Until 2026-05-16 sincronizar_precio_con_descuento ran on every save regardless of
  # estado_id, which silently reset precio_con_descuento and produced ~600 cases of
  # ps_total != renglones_total on already-billed pedidos.
  describe 'protection on confirmed pedidos (Bug B)' do
    let(:ps_persistido) do
      ps = described_class.new(pedido: pedido, producto: producto, cantidad: 2,
                               precio_unitario: 100, precio_con_descuento: 80)
      ps.save!
      ps
    end

    before { ps_persistido }

    context 'when pedido is confirmado (estado 3)' do
      before do
        pedido.update_columns(estado_id: 3, facturado: true)
        ps_persistido.reload
      end

      it 'does not reset precio_con_descuento when ps is saved' do
        # Trigger a write that previously hit sincronizar_precio_con_descuento.
        ps_persistido.precio_unitario = 120
        ps_persistido.save(validate: false)
        expect(ps_persistido.reload.precio_con_descuento.to_f).to eq(80.0)
      end

      it 'rejects updates to cantidad' do
        ps_persistido.cantidad = 99
        expect(ps_persistido).not_to be_valid
        expect(ps_persistido.errors[:pedido].join).to match(/pendiente/i)
      end

      it 'rejects updates to precio_unitario' do
        ps_persistido.precio_unitario = 250
        expect(ps_persistido).not_to be_valid
        expect(ps_persistido.errors[:pedido].join).to match(/pendiente/i)
      end
    end

    context 'when pedido is pendiente (estado 1)' do
      it 'allows updates' do
        ps_persistido.cantidad = 5
        expect(ps_persistido).to be_valid
        expect { ps_persistido.save! }.not_to raise_error
      end

      it 'still syncs precio_con_descuento when precio_unitario is set' do
        ps_persistido.precio_con_descuento = nil
        # Bypass asignar_precio which would re-fetch from the precio table.
        allow(ps_persistido).to receive(:asignar_precio)
        ps_persistido.precio_unitario = 200
        ps_persistido.save!
        expect(ps_persistido.reload.precio_con_descuento.to_f).to eq(200.0)
      end
    end
  end
end
