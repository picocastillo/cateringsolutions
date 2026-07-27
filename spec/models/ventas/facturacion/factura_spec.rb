require 'rails_helper'

RSpec.describe Ventas::Facturacion::Factura, type: :model do
  let(:tienda) { create(:tienda) }
  let(:cliente) { create(:cliente, tienda: tienda) }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:categoria) { Productos::Categoria.create!(nombre: 'Cat Factura', tienda: tienda) }
  let(:producto) { Productos::Producto.create!(nombre: 'Prod Factura', categoria: categoria, tienda: tienda) }
  let(:producto_b) { Productos::Producto.create!(nombre: 'Prod Factura B', categoria: categoria, tienda: tienda) }
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
    let(:factura) { described_class.new }

    describe '#factura?' do
      it 'returns true' do
        expect(factura.factura?).to be true
      end
    end

    describe '#debita?' do
      it 'returns true' do
        expect(factura.debita?).to be true
      end
    end

    describe '#rol_asociado' do
      it 'returns facturar symbol' do
        expect(factura.rol_asociado).to eq :facturar
      end
    end

    describe '#cobrar_e_imputar' do
      it 'responds to cobrar_e_imputar method' do
        expect(factura).to respond_to(:cobrar_e_imputar)
      end

      it 'accepts user parameter' do
        expect(factura.method(:cobrar_e_imputar).arity).to eq(1)
      end
    end
  end

  describe 'callbacks' do
    describe '#asignar_tipo' do
      it 'assigns tipo with codigo 1 for new records' do
        factura = described_class.new
        factura.send(:asignar_tipo)
        expect(factura.tipo).to eq tipo_factura
      end

      it 'does not assign tipo for existing records' do
        factura = described_class.new
        allow(factura).to receive(:new_record?).and_return(false)
        factura.send(:asignar_tipo)
        expect(factura.tipo).to be_nil
      end
    end
  end

  describe 'factura creation with renglones' do
    it 'creates factura with full price renglones' do
      factura = described_class.create!(
        tienda: tienda, cuenta: cuenta, autor: usuario,
        fecha_emision: Time.current, completar_on_save: true,
        renglones: [
          { producto: producto, cantidad: 2, precio_unitario: 300, descripcion: 'Prod A' },
          { producto: producto_b, cantidad: 3, precio_unitario: 200, descripcion: 'Prod B' }
        ]
      )
      expect(factura).to be_persisted
      expect(factura.renglones.count).to eq(2)
      expect(factura.total_sin_iva.to_f).to eq(1200)
    end

    it 'computes subtotales on save when completar_on_save is true' do
      factura = described_class.create!(
        tienda: tienda, cuenta: cuenta, autor: usuario,
        fecha_emision: Time.current, completar_on_save: true,
        renglones: [{ producto: producto, cantidad: 1, precio_unitario: 100, descripcion: 'Prod' }]
      )
      expect(factura.subtotales.count).to be >= 1
      expect(factura.total.to_f).to be > 0
    end
  end

  describe 'factura with cupon discount creates NC' do
    let(:cupon) { create(:cupon, tienda: tienda, tipo_descuento: 'importe', importe: 200) }
    let(:producto2) { Productos::Producto.create!(nombre: 'Prod B', categoria: categoria, tienda: tienda) }

    let(:pedido) do
      p = create(:pedido, tienda: tienda, cuenta: cuenta, fecha: Date.current, estado_id: 1, autor: usuario, usuario: usuario)
      p
    end

    let(:factura) do
      Ventas::Facturacion::Factura.create!(
        tienda: tienda, cuenta: cuenta, pedido: pedido, autor: usuario,
        fecha_emision: Time.current, completar_on_save: true,
        renglones: [
          { producto: producto, cantidad: 2, precio_unitario: 300, descripcion: producto.to_s },
          { producto: producto2, cantidad: 3, precio_unitario: 200, descripcion: producto2.to_s }
        ]
      )
    end

    before do
      ps1 = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto, cantidad: 2, precio_unitario: 300, precio_con_descuento: 300)
      ps1.save(validate: false)
      ps2 = Productos::ProductoSolicitado.new(pedido: pedido, producto: producto2, cantidad: 3, precio_unitario: 200, precio_con_descuento: 200)
      ps2.save(validate: false)
      pedido.productos_solicitados.reload
    end

    it 'crear_nc_descuento creates NC with discount renglones' do
      # Simulate cupon: $200 discount distributed proportionally
      pedido.productos_solicitados[0].update_columns(precio_con_descuento: 250)
      pedido.productos_solicitados[1].update_columns(precio_con_descuento: 166.67)
      pedido.update_columns(cupon_id: cupon.id)
      pedido.productos_solicitados.reload
      pedido.reload

      pedido.send(:crear_nc_descuento, factura)

      nc = Ventas::Facturacion::NotaCredito.last
      expect(nc).to be_present
      # May include adjustment renglon for rounding
      expect(nc.renglones.count).to be >= 2
      nc.renglones.each do |r|
        expect(r.descripcion).to include('cupón')
        expect(r.precio_unitario.to_f).to be > 0
      end
      # NC total must exactly match the cupon discount
      expect(nc.total_sin_iva.to_f).to eq(200.0)
    end

    it 'does not create NC when no discount on productos' do
      # precio_con_descuento == precio_unitario, so tiene_descuento? is false
      expect { pedido.send(:crear_nc_descuento, factura) }.not_to(change(Ventas::Facturacion::NotaCredito, :count))
    end

    it 'NC total equals discount for porcentaje cupon' do
      # Simulate 10% cupon: 10% of 1200 = 120
      cupon_pct = create(:cupon, :porcentaje, tienda: tienda, porcentaje: 10, limite_bonificacion: 500)
      pedido.productos_solicitados[0].update_columns(precio_con_descuento: 270)
      pedido.productos_solicitados[1].update_columns(precio_con_descuento: 180)
      pedido.update_columns(cupon_id: cupon_pct.id)
      pedido.productos_solicitados.reload
      pedido.reload

      pedido.send(:crear_nc_descuento, factura)

      nc = Ventas::Facturacion::NotaCredito.last
      expect(nc).to be_present
      expect(nc.total_sin_iva.to_f).to eq(120.0)
    end

    it 'factura uses full precio_unitario not precio_con_descuento' do
      expect(factura.renglones.count).to eq(2)
      factura.renglones.each do |r|
        expect(r.precio_unitario.to_f).to be_in([300.0, 200.0])
      end
      expect(factura.total_sin_iva.to_f).to eq(1200)
    end
  end

  describe '#cobrar_e_imputar' do
    let!(:tipo_recibo) do
      Comprobantes::Tipo.find_or_create_by!(codigo: 4) do |t|
        t.desc = 'Recibo'
        t.clase = 'Cobros::Recibo'
        t.letra = 'X'
        t.debitan = false
      end
    end

    let(:factura) do
      described_class.create!(
        tienda: tienda, cuenta: cuenta, autor: usuario,
        fecha_emision: Time.current, completar_on_save: true,
        renglones: [
          { producto: producto, cantidad: 2, precio_unitario: 300, descripcion: 'Prod A' }
        ]
      )
    end

    let(:pedido) do
      p = create(:pedido, tienda: tienda, cuenta: cuenta, fecha: Date.current, estado_id: 1, autor: usuario, usuario: usuario)
      p
    end

    before do
      # Confirm the factura so cobrar_e_imputar can run (needs saldo > 0)
      factura.update_columns(estado_id: 2) # confirmado
      factura.update!(pedido: pedido) if factura.pedido.nil?
    end

    context 'when medio_de_pago is nil (non-MercadoPago flow)' do
      context 'with default (no medio_pago_tipo on pedido)' do
        it 'creates recibo with Efectivo' do
          expected_amount = factura.saldo.to_f
          expect { factura.cobrar_e_imputar(usuario) }.to change(Logistica::Flujos::Efectivo, :count).by(1)

          recibo = Cobros::Recibo.last
          expect(recibo).to be_present
          expect(recibo.efectivos.count).to eq(1)
          expect(recibo.efectivos.first.importe.to_f).to eq(expected_amount)
        end
      end

      context 'with medio_pago_tipo = debito' do
        before { pedido.update_column(:medio_pago_tipo, 'debito') }

        it 'creates recibo with Debito' do
          expected_amount = factura.saldo.to_f
          expect { factura.cobrar_e_imputar(usuario) }.to change(Logistica::Flujos::Debito, :count).by(1)

          recibo = Cobros::Recibo.last
          expect(recibo.debitos.count).to eq(1)
          expect(recibo.debitos.first.importe.to_f).to eq(expected_amount)
        end
      end

      context 'with medio_pago_tipo = credito' do
        before { pedido.update_column(:medio_pago_tipo, 'credito') }

        it 'creates recibo with Credito' do
          expect { factura.cobrar_e_imputar(usuario) }.to change(Logistica::Flujos::Credito, :count).by(1)

          recibo = Cobros::Recibo.last
          expect(recibo.creditos.count).to eq(1)
        end
      end

      context 'with medio_pago_tipo = qr' do
        before { pedido.update_column(:medio_pago_tipo, 'qr') }

        it 'creates recibo with Qr' do
          expect { factura.cobrar_e_imputar(usuario) }.to change(Logistica::Flujos::Qr, :count).by(1)

          recibo = Cobros::Recibo.last
          expect(recibo.qrs.count).to eq(1)
        end
      end

      context 'with medio_pago_tipo = transferencia' do
        before { pedido.update_column(:medio_pago_tipo, 'transferencia') }

        it 'creates recibo with Transferencia' do
          expect { factura.cobrar_e_imputar(usuario) }.to change(Logistica::Flujos::Transferencia, :count).by(1)

          recibo = Cobros::Recibo.last
          expect(recibo.transferencias.count).to eq(1)
        end
      end

      context 'with medio_pago_tipo = efectivo (explicit)' do
        before { pedido.update_column(:medio_pago_tipo, 'efectivo') }

        it 'creates recibo with Efectivo' do
          expect { factura.cobrar_e_imputar(usuario) }.to change(Logistica::Flujos::Efectivo, :count).by(1)
        end
      end

      it 'creates afectacion linking recibo to factura' do
        expected_amount = factura.saldo.to_f
        factura.cobrar_e_imputar(usuario)

        recibo = Cobros::Recibo.last
        expect(recibo.afectaciones.count).to eq(1)
        expect(recibo.afectaciones.first.afectado).to eq(factura)
        expect(recibo.afectaciones.first.importe.to_f).to eq(expected_amount)
      end
    end
  end
end
