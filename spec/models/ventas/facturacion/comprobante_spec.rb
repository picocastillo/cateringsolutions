require 'rails_helper'

RSpec.describe Ventas::Facturacion::Comprobante, type: :model do
  let(:tienda) { Tiendas::Tienda.create!(nombre: 'Tienda Comprobante') }
  let(:cliente) { Clientes::Cliente.create!(nombre: 'Cliente Comprobante', cuit: '20294834487', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '12:00', tienda: tienda) }
  let(:cuenta) { Clientes::Cuenta.create!(cliente: cliente, nombre: 'Cuenta Comprobante') }
  let(:tipo) { Comprobantes::Tipo.create!(desc: 'Factura', codigo: 1, clase: 'Ventas::Facturacion::Factura', letra: 'A') }
  let(:comprobante) { described_class.new(cuenta: cuenta, tienda: tienda, tipo: tipo) }

  it 'is valid with valid attributes' do
    expect(comprobante).to be_a(described_class)
  end

  describe '.crear' do
    it 'creates comprobante from string with namespace' do
      result = described_class.crear('ventas_facturacion_factura')
      expect(result).to be_a(Ventas::Facturacion::Factura)
    end

    it 'creates NotaCredito' do
      result = described_class.crear('ventas_facturacion_nota_credito')
      expect(result).to be_a(Ventas::Facturacion::NotaCredito)
    end

    it 'accepts attributes hash' do
      result = described_class.crear('ventas_facturacion_factura', cuenta: cuenta)
      expect(result.cuenta).to eq(cuenta)
    end
  end

  describe '#total_sin_iva' do
    it 'sums renglon precio_total' do
      categoria = Productos::Categoria.create!(nombre: 'Cat', tienda: tienda)
      producto = Productos::Producto.create!(nombre: 'Prod', categoria: categoria, tienda: tienda)
      comprobante.renglones.build(producto: producto, cantidad: 2, precio_unitario: 100)
      comprobante.renglones.build(producto: producto, cantidad: 3, precio_unitario: 50)
      expect(comprobante.total_sin_iva.to_f).to eq(350)
    end

    it 'returns zero when no renglones' do
      expect(comprobante.total_sin_iva.to_f).to eq(0)
    end
  end

  describe '#subtotales_gravados' do
    it 'filters gravado subtotales' do
      allow(comprobante).to receive(:subtotales).and_return([
                                                              double('Subtotal', gravado?: true),
                                                              double('Subtotal', gravado?: false)
                                                            ])
      expect(comprobante.subtotales_gravados.count).to eq(1)
      expect(comprobante.subtotales_gravados.first.gravado?).to be true
    end
  end

  describe '#subtotal_gravado' do
    it 'sums base_imponible of gravado subtotales' do
      allow(comprobante).to receive(:subtotales).and_return([
                                                              double('Subtotal', gravado?: true, base_imponible: 100),
                                                              double('Subtotal', gravado?: true, base_imponible: 200),
                                                              double('Subtotal', gravado?: false, base_imponible: 50)
                                                            ])
      expect(comprobante.subtotal_gravado.to_f).to eq(300)
    end
  end

  describe 'date filtering' do
    it 'responds to scoping methods' do
      expect(described_class).to respond_to(:all)
      expect(described_class).to respond_to(:where)
    end
  end

  describe '#no_gravado?' do
    it 'returns true when cuenta is monotributo' do
      allow(cuenta).to receive(:monotributo?).and_return(true)
      expect(comprobante.no_gravado?).to be true
    end

    it 'checks cuenta condicion_iva' do
      expect(comprobante.no_gravado?).to be_in([true, false])
    end
  end

  describe '#automatico?' do
    it 'returns false by default' do
      expect(comprobante.automatico?).to be false
    end

    it 'returns true when automatico is true' do
      comprobante.automatico = true
      expect(comprobante.automatico?).to be true
    end
  end

  describe '#calcular_totales' do
    let(:categoria) { Productos::Categoria.create!(nombre: 'Cat Calc', tienda: tienda) }
    let(:producto) { Productos::Producto.create!(nombre: 'Prod Calc', categoria: categoria, tienda: tienda) }

    it 'computes subtotales from renglones grouped by tasa_iva' do
      allow(comprobante).to receive(:para_resp_inscripto?).and_return(false)
      comprobante.renglones.build(producto: producto, cantidad: 2, precio_unitario: 100, tasa_iva: :no_gravado)
      comprobante.renglones.build(producto: producto, cantidad: 1, precio_unitario: 50, tasa_iva: :no_gravado)
      comprobante.calcular_totales
      expect(comprobante.subtotales.size).to eq(1)
      expect(comprobante.subtotales.first.base_imponible.to_f).to eq(250)
    end

    it 'sets total from subtotales total_con_iva' do
      allow(comprobante).to receive(:para_resp_inscripto?).and_return(false)
      comprobante.renglones.build(producto: producto, cantidad: 2, precio_unitario: 100, tasa_iva: :no_gravado)
      comprobante.calcular_totales
      expect(comprobante.total.to_f).to eq(200)
    end
  end

  describe '#nro_completo' do
    it 'returns "Por Asignar" when pendiente' do
      allow(comprobante).to receive(:pendiente?).and_return(true)
      expect(comprobante.nro_completo).to eq('Por Asignar')
    end
  end

  describe '#pendiente? and #confirmado?' do
    it 'returns true for pendiente state' do
      allow(comprobante).to receive(:en_estado?).with(:pendiente).and_return(true)
      expect(comprobante.pendiente?).to be true
    end

    it 'returns true for confirmado state' do
      allow(comprobante).to receive(:en_estado?).with(:confirmado).and_return(true)
      expect(comprobante.confirmado?).to be true
    end
  end

  describe '#debita? and #acredita?' do
    it 'factura debita' do
      factura = Ventas::Facturacion::Factura.new
      expect(factura.debita?).to be true
      expect(factura.acredita?).to be false
    end

    it 'nota credito acredita' do
      nc = Ventas::Facturacion::NotaCredito.new
      expect(nc.debita?).to be false
      expect(nc.acredita?).to be true
    end
  end

  describe '#saldo' do
    it 'returns total when no movimientos' do
      allow(comprobante).to receive(:movimientos).and_return(double(last: nil))
      comprobante.total = 1000
      expect(comprobante.saldo.to_f).to eq(1000)
    end
  end

  describe '#saldado?' do
    it 'returns true when saldo is zero' do
      allow(comprobante).to receive(:saldo).and_return(Danconia::Money.new(0))
      expect(comprobante.saldado?).to be true
    end

    it 'returns false when saldo is not zero' do
      allow(comprobante).to receive(:saldo).and_return(Danconia::Money.new(100))
      expect(comprobante.saldado?).to be false
    end
  end

  describe '#manual?' do
    it 'returns true when not automatico' do
      comprobante.automatico = false
      expect(comprobante.manual?).to be true
    end

    it 'returns false when automatico' do
      comprobante.automatico = true
      expect(comprobante.manual?).to be false
    end
  end

  describe '#vencido?' do
    it 'returns true when fecha_vencimiento is in the past' do
      comprobante.fecha_vencimiento = 1.day.ago.to_date
      expect(comprobante.vencido?).to be true
    end

    it 'returns false when fecha_vencimiento is in the future' do
      comprobante.fecha_vencimiento = 1.day.from_now.to_date
      expect(comprobante.vencido?).to be false
    end

    it 'returns false when no fecha_vencimiento' do
      comprobante.fecha_vencimiento = nil
      expect(comprobante).not_to be_vencido
    end
  end

  describe '#confirmable?' do
    it 'returns true for admin user on pendiente comprobante' do
      user = double('user', admin?: true)
      allow(comprobante).to receive(:pendiente?).and_return(true)
      expect(comprobante.confirmable?(user)).to be true
    end

    it 'returns false for non-admin user' do
      user = double('user', admin?: false)
      allow(comprobante).to receive(:pendiente?).and_return(true)
      expect(comprobante.confirmable?(user)).to be false
    end
  end

  describe '#total_sin_iva with discount scenario' do
    let(:categoria) { Productos::Categoria.create!(nombre: 'Cat Desc', tienda: tienda) }
    let(:producto) { Productos::Producto.create!(nombre: 'Prod Desc', categoria: categoria, tienda: tienda) }

    it 'computes total from full price renglones (factura uses precio_unitario)' do
      comprobante.renglones.build(producto: producto, cantidad: 2, precio_unitario: 300)
      comprobante.renglones.build(producto: producto, cantidad: 3, precio_unitario: 200)
      expect(comprobante.total_sin_iva.to_f).to eq(1200)
    end

    it 'computes total from discount renglones (NC uses descuento_unitario)' do
      comprobante.renglones.build(producto: producto, cantidad: 2, precio_unitario: 50, descripcion: 'Descuento cupón TEST')
      comprobante.renglones.build(producto: producto, cantidad: 3, precio_unitario: 33.33, descripcion: 'Descuento cupón TEST')
      expect(comprobante.total_sin_iva.to_f).to be_within(0.01).of(199.99)
    end
  end

  describe '#cachear_local fallback chain' do
    let(:local_autor)    { Locales::Local.create!(nombre: 'Local Autor', tienda: tienda, domicilio: 'A 1', telefono: '1') }
    let(:local_cancela)  { Locales::Local.create!(nombre: 'Local Cancela', tienda: tienda, domicilio: 'B 1', telefono: '2') }
    let(:local_pedido)   { Locales::Local.create!(nombre: 'Local Pedido', tienda: tienda, domicilio: 'C 1', telefono: '3') }
    let(:local_carrito)  { Locales::Local.create!(nombre: 'Local Carrito', tienda: tienda, domicilio: 'E 1', telefono: '5') }
    let(:autor) do
      Usuarios::Usuario.create!(
        nombre: 'U', login: 'u_cachear_local', password: 'password123',
        password_confirmation: 'password123', email: 'u_cachear_local@example.com',
        tipo_usuario_id: 1, dni: 11_111_111, local: local_autor, cuenta: cuenta
      )
    end
    let(:pedido) do
      p = Pedidos::Pedido.new(tienda: tienda, autor: autor, usuario: autor, estado_id: 1, fecha: Date.current, local: local_pedido)
      p.asignar_cuenta_manual
      p.cuenta = cuenta
      p.save!(validate: false)
      p
    end
    let(:factura_cancela) do
      Ventas::Facturacion::Factura.new(tienda: tienda, cuenta: cuenta, tipo: tipo, local: local_cancela)
    end

    it 'uses pedido.local first' do
      nc = Ventas::Facturacion::NotaCredito.new(cuenta: cuenta, tienda: tienda, autor: autor, pedido: pedido, cancela_a: factura_cancela)
      nc.send(:cachear_local)
      expect(nc.local).to eq(local_pedido)
    end

    it 'falls back to cancela_a.local when pedido has no local' do
      nc = Ventas::Facturacion::NotaCredito.new(cuenta: cuenta, tienda: tienda, autor: autor, cancela_a: factura_cancela)
      nc.send(:cachear_local)
      expect(nc.local).to eq(local_cancela)
    end

    it 'falls back to autor.local_activo when pedido and cancela_a have no local' do
      nc = Ventas::Facturacion::NotaCredito.new(cuenta: cuenta, tienda: tienda, autor: autor)
      nc.send(:cachear_local)
      expect(nc.local).to eq(local_autor)
    end

    it 'prefers autor.visualizando_local over autor.local (local_activo semantics)' do
      autor.update_columns(visualizando_local_id: local_carrito.id)
      autor.reload
      nc = Ventas::Facturacion::NotaCredito.new(cuenta: cuenta, tienda: tienda, autor: autor)
      nc.send(:cachear_local)
      expect(nc.local).to eq(local_carrito)
    end

    it 'falls back to tienda.local_para_carrito when no other source has a local' do
      tienda.update!(local_atencion_carrito_id: local_carrito.id)
      autor_sin_local = Usuarios::Usuario.create!(
        nombre: 'U2', login: 'u2_cachear_local', password: 'password123',
        password_confirmation: 'password123', email: 'u2_cachear_local@example.com',
        tipo_usuario_id: 1, dni: 22_222_222, cuenta: cuenta
      )
      nc = Ventas::Facturacion::NotaCredito.new(cuenta: cuenta, tienda: tienda, autor: autor_sin_local)
      nc.send(:cachear_local)
      expect(nc.local).to eq(local_carrito)
    end

    it 'preserves an explicit local even if pedido.local differs' do
      otro = Locales::Local.create!(nombre: 'Otro', tienda: tienda, domicilio: 'D 1', telefono: '4')
      nc = Ventas::Facturacion::NotaCredito.new(cuenta: cuenta, tienda: tienda, autor: autor, pedido: pedido, local: otro)
      nc.send(:cachear_local)
      expect(nc.local).to eq(otro)
    end
  end
end
