require 'rails_helper'

RSpec.describe VentasMostrador::DescuentoVentaMostrador, type: :model do
  let(:tienda) { create(:tienda) }
  let(:cliente) { create(:cliente, tienda: tienda) }

  describe 'associations' do
    it { is_expected.to belong_to(:tienda) }
  end

  describe '#to_s' do
    it 'returns the nombre' do
      d = build(:descuento_venta_mostrador, tienda: tienda, nombre: 'Mi Descuento')
      expect(d.to_s).to eq('Mi Descuento')
    end
  end

  describe 'scopes' do
    it '.activos returns only active records' do
      active = create(:descuento_venta_mostrador, tienda: tienda, activo: true)
      create(:descuento_venta_mostrador, :inactivo, tienda: tienda, nombre: 'Inactivo')
      expect(described_class.activos).to eq([active])
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:nombre) }
    it { is_expected.to validate_presence_of(:tipo_descuento) }
    it { is_expected.to validate_inclusion_of(:medio_pago_tipo).in_array(Pedidos::MedioPago::TIPOS.keys).allow_blank }
    it { is_expected.to validate_presence_of(:importe_minimo) }

    context 'when tipo_descuento is importe' do
      subject { build(:descuento_venta_mostrador, tipo_descuento: 'importe', tienda: tienda) }

      it { is_expected.to validate_presence_of(:importe) }
      it { is_expected.to validate_numericality_of(:importe).is_greater_than(0) }
    end

    context 'when tipo_descuento is porcentaje' do
      subject { build(:descuento_venta_mostrador, :porcentaje_con_limite, tienda: tienda) }

      it { is_expected.to validate_presence_of(:porcentaje) }
      it { is_expected.to validate_presence_of(:limite_bonificacion) }
    end

    it 'rejects invalid medio_pago_tipo' do
      d = build(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: 'bitcoin')
      expect(d).not_to be_valid
      expect(d.errors[:medio_pago_tipo]).to be_present
    end
  end

  describe '#descuento_para' do
    it 'returns importe for importe type (capped at total)' do
      d = build(:descuento_venta_mostrador, tienda: tienda, tipo_descuento: 'importe', importe: 500)
      expect(d.descuento_para(10_000)).to eq(500)
      expect(d.descuento_para(300)).to eq(300) # capped at total
    end

    it 'returns percentage for porcentaje type (capped at limite)' do
      d = build(:descuento_venta_mostrador, :porcentaje_con_limite, tienda: tienda,
                                                                    porcentaje: 10, limite_bonificacion: 2000)
      expect(d.descuento_para(10_000)).to eq(1000) # 10% of 10000
      expect(d.descuento_para(30_000)).to eq(2000) # capped at limite
    end
  end

  describe '#descuento_descripcion' do
    it 'shows dollar amount for importe type' do
      d = build(:descuento_venta_mostrador, tienda: tienda, importe: 500)
      expect(d.descuento_descripcion).to eq('$500')
    end

    it 'shows percentage without limit for porcentaje type' do
      d = build(:descuento_venta_mostrador, :porcentaje_con_limite, tienda: tienda,
                                                                    porcentaje: 10, limite_bonificacion: 2000)
      expect(d.descuento_descripcion).to eq('10%')
    end
  end

  describe '#limite_bonificacion_descripcion' do
    it 'returns formatted limit for porcentaje type' do
      d = build(:descuento_venta_mostrador, :porcentaje_con_limite, tienda: tienda,
                                                                    porcentaje: 10, limite_bonificacion: 2000)
      expect(d.limite_bonificacion_descripcion).to eq('$2000')
    end

    it 'returns nil for importe type' do
      d = build(:descuento_venta_mostrador, tienda: tienda, importe: 500)
      expect(d.limite_bonificacion_descripcion).to be_nil
    end
  end

  describe '#medio_pago_label' do
    it 'returns the human name for the medio de pago' do
      d = build(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: 'qr')
      expect(d.medio_pago_label).to eq('QR')
    end

    it 'returns Todos when medio_pago_tipo is blank' do
      d = build(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: '')
      expect(d.medio_pago_label).to eq('Todos')
    end
  end

  describe '#aplicable_a_cliente?' do
    it 'returns true when no clientes (applies to all)' do
      d = create(:descuento_venta_mostrador, tienda: tienda)
      expect(d.aplicable_a_cliente?(cliente)).to be true
    end

    it 'returns true when the cliente is in the list' do
      d = create(:descuento_venta_mostrador, tienda: tienda)
      d.clientes << cliente
      expect(d.aplicable_a_cliente?(cliente)).to be true
    end

    it 'returns false when the cliente is not in the list' do
      d = create(:descuento_venta_mostrador, tienda: tienda)
      d.clientes << create(:cliente, tienda: tienda)
      expect(d.aplicable_a_cliente?(cliente)).to be false
    end
  end

  describe '#aplicable?' do
    let(:descuento) { create(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: 'efectivo', importe_minimo: 5000) }

    it 'returns true when all conditions match' do
      expect(descuento.aplicable?(medio_pago_tipo: 'efectivo', importe_total: 10_000, cliente: cliente)).to be true
    end

    it 'returns false for wrong medio de pago' do
      expect(descuento.aplicable?(medio_pago_tipo: 'qr', importe_total: 10_000, cliente: cliente)).to be false
    end

    it 'returns false when importe is below minimum' do
      expect(descuento.aplicable?(medio_pago_tipo: 'efectivo', importe_total: 3000, cliente: cliente)).to be false
    end

    context 'with blank medio_pago_tipo (todos)' do
      let(:descuento_todos) { create(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: '', importe_minimo: 0) }

      it 'matches any medio de pago' do
        expect(descuento_todos.aplicable?(medio_pago_tipo: 'efectivo', importe_total: 10_000, cliente: cliente)).to be true
        expect(descuento_todos.aplicable?(medio_pago_tipo: 'qr', importe_total: 10_000, cliente: cliente)).to be true
        expect(descuento_todos.aplicable?(medio_pago_tipo: 'transferencia', importe_total: 10_000, cliente: cliente)).to be true
      end
    end

    it 'returns false when inactive' do
      descuento.update!(activo: false)
      expect(descuento.aplicable?(medio_pago_tipo: 'efectivo', importe_total: 10_000, cliente: cliente)).to be false
    end
  end

  describe '.mejor_descuento_para' do
    it 'returns the discount with the highest absolute amount' do
      create(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: 'efectivo',
                                         importe: 500, importe_minimo: 0)
      d2 = create(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: 'efectivo',
                                              importe: 1000, importe_minimo: 0, nombre: 'Mejor')

      result = described_class.mejor_descuento_para(
        tienda: tienda, cliente: cliente, medio_pago_tipo: 'efectivo', importe_total: 20_000
      )
      expect(result).to eq(d2)
    end

    it 'ignores inactive discounts' do
      create(:descuento_venta_mostrador, :inactivo, tienda: tienda, medio_pago_tipo: 'efectivo',
                                                    importe: 5000, importe_minimo: 0)
      d_active = create(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: 'efectivo',
                                                    importe: 100, importe_minimo: 0, nombre: 'Pequeño')

      result = described_class.mejor_descuento_para(
        tienda: tienda, cliente: cliente, medio_pago_tipo: 'efectivo', importe_total: 20_000
      )
      expect(result).to eq(d_active)
    end

    it 'returns nil when no discounts match' do
      create(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: 'qr', importe_minimo: 0)

      result = described_class.mejor_descuento_para(
        tienda: tienda, cliente: cliente, medio_pago_tipo: 'efectivo', importe_total: 20_000
      )
      expect(result).to be_nil
    end

    it 'filters by client when descuento has specific clientes' do
      otro_cliente = create(:cliente, tienda: tienda)
      d = create(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: 'efectivo',
                                             importe: 1000, importe_minimo: 0, nombre: 'Solo Otro')
      d.clientes << otro_cliente

      result = described_class.mejor_descuento_para(
        tienda: tienda, cliente: cliente, medio_pago_tipo: 'efectivo', importe_total: 20_000
      )
      expect(result).to be_nil
    end

    it 'matches blank medio_pago_tipo (todos) regardless of payment type' do
      d = create(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: '',
                                             importe: 800, importe_minimo: 0, nombre: 'Todos MP')

      ['efectivo', 'qr', 'debito', 'credito', 'transferencia'].each do |tipo|
        result = described_class.mejor_descuento_para(
          tienda: tienda, cliente: cliente, medio_pago_tipo: tipo, importe_total: 20_000
        )
        expect(result).to eq(d), "Expected 'Todos MP' to match medio_pago_tipo '#{tipo}'"
      end
    end

    it 'picks the best between specific and todos discounts' do
      create(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: 'efectivo',
                                         importe: 500, importe_minimo: 0, nombre: 'Efectivo $500')
      d_todos = create(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: '',
                                                   importe: 1000, importe_minimo: 0, nombre: 'Todos $1000')

      result = described_class.mejor_descuento_para(
        tienda: tienda, cliente: cliente, medio_pago_tipo: 'efectivo', importe_total: 20_000
      )
      expect(result).to eq(d_todos)
    end

    it 'compares using importe_medio for medio-specific discounts' do
      # 10% on efectivo with limit $99999 — on $1500 medio = $150
      create(:descuento_venta_mostrador, :porcentaje_con_limite, tienda: tienda,
                                                                 medio_pago_tipo: 'efectivo',
                                                                 porcentaje: 10,
                                                                 limite_bonificacion: 99_999,
                                                                 importe_minimo: 0, nombre: 'Efectivo 10%')
      # $200 fixed on todos (no medio, uses total) = $200
      d_todos = create(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: '',
                                                   importe: 200, importe_minimo: 0, nombre: 'Todos $200')

      # Total=$2000, efectivo=$1500. 10% of $1500 = $150 < $200 fixed → todos wins
      result = described_class.mejor_descuento_para(
        tienda: tienda, cliente: cliente, medio_pago_tipo: 'efectivo',
        importe_total: 2000, importe_medio: 1500
      )
      expect(result).to eq(d_todos)
    end
  end

  describe '#descuento_para with importe_medio' do
    it 'uses importe_medio as base for medio-specific percentage discount' do
      d = build(:descuento_venta_mostrador, :porcentaje_con_limite, tienda: tienda,
                                                                    medio_pago_tipo: 'efectivo',
                                                                    porcentaje: 10,
                                                                    limite_bonificacion: 99_999)
      # 10% of $1500 medio (not $2000 total)
      expect(d.descuento_para(2000, importe_medio: 1500)).to eq(150.0)
    end

    it 'uses importe_total as base for "todos" (blank medio) discount' do
      d = build(:descuento_venta_mostrador, :porcentaje_con_limite, tienda: tienda,
                                                                    medio_pago_tipo: '',
                                                                    porcentaje: 10,
                                                                    limite_bonificacion: 99_999)
      # 10% of $2000 total (ignores importe_medio)
      expect(d.descuento_para(2000, importe_medio: 1500)).to eq(200.0)
    end

    it 'uses importe_medio for medio-specific importe discount (capped)' do
      d = build(:descuento_venta_mostrador, tienda: tienda, medio_pago_tipo: 'efectivo',
                                            tipo_descuento: 'importe', importe: 500)
      # importe cap: min(500, 300 medio) = 300
      expect(d.descuento_para(2000, importe_medio: 300)).to eq(300.0)
    end

    it 'returns 0 when importe_total is 0' do
      d = build(:descuento_venta_mostrador, :porcentaje_con_limite, tienda: tienda,
                                                                    porcentaje: 10,
                                                                    limite_bonificacion: 99_999)
      expect(d.descuento_para(0)).to eq(0.0)
    end
  end

  describe 'pedido integration' do
    let(:cuenta) { create(:cuenta, cliente: cliente) }
    let(:usuario) do
      create(:usuario, :admin, visualizando_tienda: tienda).tap do |u|
        u.tiendas << tienda unless u.tiendas.include?(tienda)
        u.update_column(:cuenta_id, cuenta.id)
      end
    end
    let(:categoria) do
      create(:categoria, nombre: 'Cat Test', tienda: tienda, stock_activo: false, menu_diario: false).tap do |cat|
        cliente.categorias << cat unless cliente.categorias.include?(cat)
      end
    end
    let(:producto) { create(:producto, nombre: 'Prod Test', tienda: tienda, categoria: categoria) }

    let(:pedido) do
      p = Pedidos::Pedido.new(
        autor: usuario, cuenta: cuenta, usuario: usuario,
        fecha: Date.current, estado_id: 1,
        tienda_id: tienda.id, venta_mostrador: true
      )
      p.asignar_cuenta_manual
      p.cuenta = cuenta
      p.no_validar_fecha = true
      p.save!
      p
    end

    before do
      create(:categoria, nombre: 'Menu Diario', tienda: tienda, menu_diario: true)
      create(:precio, producto: producto, importe: 200.0,
                      fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)

      Comprobantes::Tipo.find_or_create_by(codigo: 1) do |tipo|
        tipo.desc = 'Factura'
        tipo.clase = 'Ventas::Facturacion::Factura'
        tipo.letra = 'A'
        tipo.debitan = false
      end
      Comprobantes::Tipo.find_or_create_by(codigo: 3) do |tipo|
        tipo.desc = 'Nota de Crédito'
        tipo.clase = 'Ventas::Facturacion::NotaCredito'
        tipo.letra = 'A'
        tipo.debitan = false
      end
    end

    def add_ps(ped, prod, qty, precio)
      ps = Productos::ProductoSolicitado.new(
        pedido: ped, producto: prod, cantidad: qty,
        precio_unitario: precio, precio_con_descuento: precio
      )
      ps.save(validate: false)
      ps
    end

    describe '#importe_descuento_vm / #importe_descuento_total' do
      it 'returns stored monto_descuento_vm as Money' do
        add_ps(pedido, producto, 10, 200.0) # $2000
        descuento = create(:descuento_venta_mostrador, tienda: tienda, importe: 300, importe_minimo: 0)

        pedido.descuento_venta_mostrador = descuento
        pedido.monto_descuento_vm = 300.0

        items = pedido.productos_solicitados.reload
        Cupones::DistribuidorDescuento.distribuir(items, 300.0, 2000.0)
        pedido.save!

        expect(pedido.importe_descuento_vm).to eq(Danconia::Money.new(300))
        expect(pedido.importe_descuento_total).to eq(Danconia::Money.new(300))
        expect(pedido.importe_total).to eq(Danconia::Money.new(1700))
      end

      it 'returns 0 when no VM discount' do
        add_ps(pedido, producto, 5, 200.0)
        expect(pedido.importe_descuento_vm).to eq(Danconia::Money.new(0))
        expect(pedido.importe_descuento_total).to eq(Danconia::Money.new(0))
      end
    end

    describe '#crear_nc_descuento with VM discount' do
      it 'creates a NotaCredito with the stored monto_descuento_vm amount' do
        add_ps(pedido, producto, 10, 200.0)
        descuento = create(:descuento_venta_mostrador, tienda: tienda, importe: 300,
                                                       importe_minimo: 0, nombre: 'Test $300')
        pedido.descuento_venta_mostrador = descuento
        pedido.monto_descuento_vm = 300.0
        items = pedido.productos_solicitados.reload
        Cupones::DistribuidorDescuento.distribuir(items, 300.0, 2000.0)
        pedido.instance_variable_set(:@skip_medios_validation, true)
        pedido.save!

        # Simulate factura creation
        factura = pedido.send(:crear_factura, usuario)
        expect(factura).to be_persisted

        # NC should have been created
        nc = pedido.comprobantes.reload.select { |c| c.is_a?(Ventas::Facturacion::NotaCredito) }.last
        expect(nc).to be_present
        expect(nc.total.to_f).to eq(300.0)

        nc_descriptions = nc.renglones.map(&:descripcion)
        expect(nc_descriptions.first).to include('Descuento Test $300')
      end
    end

    describe 'deleting referenced DescuentoVentaMostrador' do
      it 'nullifies pedido FK when descuento is destroyed' do
        add_ps(pedido, producto, 5, 200.0)
        descuento = create(:descuento_venta_mostrador, tienda: tienda, importe: 100, importe_minimo: 0)
        pedido.update_column(:descuento_venta_mostrador_id, descuento.id)

        descuento.destroy
        expect(pedido.reload.descuento_venta_mostrador_id).to be_nil
      end
    end

    describe 'mutual exclusivity: cupon vs VM discount' do
      it 'cupon takes precedence over VM discount (elsif)' do
        add_ps(pedido, producto, 10, 200.0)

        descuento = create(:descuento_venta_mostrador, tienda: tienda, importe: 500, importe_minimo: 0)
        pedido.descuento_venta_mostrador = descuento
        pedido.monto_descuento_vm = 500.0

        cupon = create(:cupon, tienda: tienda, tipo_descuento: 'importe', importe: 100)
        pedido.cupon = cupon

        items = pedido.productos_solicitados.reload
        Cupones::DistribuidorDescuento.distribuir(items, 100.0, 2000.0)
        pedido.instance_variable_set(:@skip_medios_validation, true)
        pedido.save!

        # cupon present → importe_descuento_cupon is used (not VM)
        expect(pedido.tiene_descuento_cupon?).to be true
        expect(pedido.importe_descuento_total).to eq(Danconia::Money.new(100))
      end
    end
  end
end
