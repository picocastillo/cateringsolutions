require 'rails_helper'

RSpec.describe Ventas::Facturacion::NotaCredito, type: :model do
  let(:tienda) { create(:tienda) }
  let(:cliente) { create(:cliente, tienda: tienda) }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:categoria) { Productos::Categoria.create!(nombre: 'Cat NC', tienda: tienda) }
  let(:producto) { Productos::Producto.create!(nombre: 'Prod NC', categoria: categoria, tienda: tienda) }
  let(:producto_b) { Productos::Producto.create!(nombre: 'Prod NC B', categoria: categoria, tienda: tienda) }
  let(:usuario) do
    user = create(:usuario, :admin, visualizando_tienda: tienda)
    user.tiendas << tienda unless user.tiendas.include?(tienda)
    user
  end

  let!(:tipo_factura) do
    Comprobantes::Tipo.find_or_create_by!(codigo: 1) do |t|
      t.desc = 'Factura'
      t.clase = 'Ventas::Facturacion::Factura'
      t.letra = 'A'
      t.debitan = true
    end
  end
  let!(:tipo_nc) do
    Comprobantes::Tipo.find_or_create_by!(codigo: 3) do |t|
      t.desc = 'Nota de Crédito'
      t.clase = 'Ventas::Facturacion::NotaCredito'
      t.letra = 'A'
      t.debitan = false
    end
  end

  describe 'inheritance' do
    it 'inherits from Comprobante' do
      expect(described_class.superclass).to eq Ventas::Facturacion::Comprobante
    end
  end

  describe 'instance methods' do
    let(:nota_credito) { described_class.new }

    describe '#nota_credito?' do
      it 'returns true' do
        expect(nota_credito.nota_credito?).to be true
      end
    end

    describe '#nota?' do
      it 'returns true' do
        expect(nota_credito.nota?).to be true
      end
    end

    describe '#debita?' do
      it 'returns false' do
        expect(nota_credito.debita?).to be false
      end
    end

    describe '#acredita?' do
      it 'returns true' do
        expect(nota_credito.acredita?).to be true
      end
    end

    describe '#rol_asociado' do
      it 'returns generar_notas_credito symbol' do
        expect(nota_credito.rol_asociado).to eq :generar_notas_credito
      end
    end

    describe '#anular!' do
      it 'responds to anular! method' do
        expect(nota_credito).to respond_to(:anular!)
      end

      it 'does not raise error when called' do
        expect { nota_credito.anular!(nil) }.not_to raise_error
      end
    end

    describe '#generar_afectaciones' do
      it 'returns self when no renglones' do
        nota_credito.renglones = []
        nota_credito.afectaciones = []
        expect(nota_credito.generar_afectaciones).to eq nota_credito
      end

      it 'builds afectaciones when renglones have comprobante_afectado' do
        comprobante_afectado = double('comprobante', id: 1)
        renglon = double('renglon', comprobante_afectado: comprobante_afectado, total_con_iva: 100)

        allow(nota_credito).to receive_messages(renglones: [renglon], afectaciones: [])
        allow(nota_credito.afectaciones).to receive(:build)

        nota_credito.generar_afectaciones
        expect(nota_credito.afectaciones).to have_received(:build)
      end

      it 'groups afectaciones by comprobante_afectado' do
        factura = double('factura', id: 1)
        r1 = double('renglon1', comprobante_afectado: factura, total_con_iva: 100)
        r2 = double('renglon2', comprobante_afectado: factura, total_con_iva: 50)

        allow(nota_credito).to receive_messages(renglones: [r1, r2], afectaciones: [])
        allow(nota_credito.afectaciones).to receive(:build)

        nota_credito.generar_afectaciones
        expect(nota_credito.afectaciones).to have_received(:build).with(afectado: factura, importe: 150)
      end
    end
  end

  describe 'class methods' do
    describe '.generar_nc_seguros' do
      it 'responds to generar_nc_seguros' do
        expect(described_class).to respond_to(:generar_nc_seguros)
      end
    end

    describe '.generar_nc_pedido' do
      it 'responds to generar_nc_pedido' do
        expect(described_class).to respond_to(:generar_nc_pedido)
      end
    end

    describe '.generar_si_corresponde' do
      it 'responds to generar_si_corresponde' do
        expect(described_class).to respond_to(:generar_si_corresponde)
      end
    end
  end

  describe 'callbacks' do
    describe '#asignar_tipo' do
      it 'assigns tipo with codigo 3 for new records' do
        nc = described_class.new
        nc.send(:asignar_tipo)
        expect(nc.tipo).to eq tipo_nc
      end
    end

    describe '#cachear_pedido' do
      it 'caches pedido from cancela_a' do
        pedido = create(:pedido, tienda: tienda, cuenta: cuenta, autor: usuario, usuario: usuario)
        factura = Ventas::Facturacion::Factura.create!(
          tienda: tienda, cuenta: cuenta, autor: usuario, pedido: pedido,
          fecha_emision: Time.current, completar_on_save: true,
          renglones: [{ producto: producto, cantidad: 1, precio_unitario: 100, descripcion: 'P' }]
        )

        nc = described_class.new
        nc.preparar_para_cancelar_a(factura, [Ventas::Facturacion::Renglon.new(producto: producto, cantidad: 1, precio_unitario: 100)], factura)
        nc.valid?
        expect(nc.pedido).to eq(pedido)
      end
    end
  end

  describe 'NC for cupon discount' do
    it 'can be created with discount renglones linked to factura' do
      pedido = create(:pedido, tienda: tienda, cuenta: cuenta, autor: usuario, usuario: usuario)
      factura = Ventas::Facturacion::Factura.create!(
        tienda: tienda, cuenta: cuenta, autor: usuario, pedido: pedido,
        fecha_emision: Time.current, completar_on_save: true,
        renglones: [
          { producto: producto, cantidad: 2, precio_unitario: 300, descripcion: 'Prod A' },
          { producto: producto_b, cantidad: 3, precio_unitario: 200, descripcion: 'Prod B' }
        ]
      )

      # Create NC with discount renglones (as crear_nc_descuento does)
      renglones_nc = [
        Ventas::Facturacion::Renglon.new(producto: producto, cantidad: 2, precio_unitario: 50, descripcion: 'Descuento cupón TEST - Prod A'),
        Ventas::Facturacion::Renglon.new(producto: producto_b, cantidad: 3, precio_unitario: 33.33, descripcion: 'Descuento cupón TEST - Prod B')
      ]

      nc = described_class.new
      nc.preparar_para_cancelar_a(factura, renglones_nc, factura)
      nc.completar_on_save = true
      nc.save!

      expect(nc).to be_persisted
      expect(nc.renglones.count).to eq(2)
      expect(nc.cancela_a).to eq(factura)
      expect(nc.pedido).to eq(pedido)
      expect(nc.total_sin_iva.to_f).to be_within(0.01).of(199.99)

      nc.renglones.each do |r|
        expect(r.descripcion).to include('Descuento cupón')
        expect(r.precio_unitario.to_f).to be > 0
      end
    end

    it 'NC total is factura total minus effective price total' do
      factura_total = 1200.0 # 2*300 + 3*200
      descuento_total = 200.0
      nc_total = descuento_total

      nc = described_class.new
      # Building renglones for the NC with discount amounts
      nc.renglones.build(producto: producto, cantidad: 2, precio_unitario: 50, descripcion: 'Descuento')
      nc.renglones.build(producto: producto, cantidad: 3, precio_unitario: 33.33, descripcion: 'Descuento')

      expect(nc.total_sin_iva.to_f).to be_within(0.01).of(nc_total)

      # Verify: factura_total - nc_total = effective total with discount
      effective = factura_total - nc.total_sin_iva.to_f
      expect(effective).to be_within(0.01).of(1000.01) # 1200 - ~200
    end
  end

  # Bug D: partial NCs are legal (e.g. crediting a single damaged item from a
  # large factura), but the cumulative confirmed NCs against a factura must
  # never exceed that factura's total. Until 2026-05-16 there was no model
  # validation, so the anular_factura flow could be invoked twice and produce
  # two full NCs that together over-credited the factura.
  describe 'cumulative NC validation (Bug D)' do
    let(:nc) { described_class.new }
    let(:factura) { double('Factura').as_null_object }

    before do
      allow(factura).to receive_messages(total: 100.0, factura?: true,
                                         confirmado?: true)
      allow(nc).to receive(:cancela_a).and_return(factura)
    end

    it 'allows a partial NC that does not exceed the factura total' do
      allow(nc).to receive_messages(total: 40.0, already_credited_against_cancela_a: 0.0)
      nc.send(:no_excede_total_factura)
      expect(nc.errors[:base]).to be_empty
    end

    it 'allows multiple partial NCs whose sum equals the factura total' do
      allow(nc).to receive_messages(total: 30.0, already_credited_against_cancela_a: 70.0)
      nc.send(:no_excede_total_factura)
      expect(nc.errors[:base]).to be_empty
    end

    it 'rejects an NC whose sum with prior confirmed NCs exceeds the factura total' do
      allow(nc).to receive_messages(total: 50.0, already_credited_against_cancela_a: 60.0)
      nc.send(:no_excede_total_factura)
      expect(nc.errors[:base].join).to match(/excede/i)
    end
  end
end
