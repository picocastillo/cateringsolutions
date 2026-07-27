require 'rails_helper'

# This spec previously covered POST /pedidos/:id/finalizar_opciones, which has
# been removed. The same validations now live inside POST .../generar_pago_ml,
# which returns a JS response. When validation fails, the response body
# disables the MercadoPago button and shows #mp-payment-validation-hint.
RSpec.describe 'Pedidos::PedidosController#generar_pago_ml validations', type: :request do
  let!(:tienda) { create(:tienda, nombre: 'Test', carrito_de_compras: true) }
  let!(:pedido) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1, fecha: Date.current + 1.day, autor: usuario, usuario: usuario)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    create(:producto_solicitado, pedido: p, producto: producto, cantidad: 1, precio_unitario: 50.0)
    p
  end
  let!(:cliente) { create(:cliente, tienda: tienda, cuenta_corriente: false, horarios_de_entrega: true) }
  let!(:cuenta) { create(:cuenta, cliente: cliente, cuenta_corriente_parcial: nil) }
  let!(:usuario) do
    create(:usuario, :admin, cuenta: cuenta, tienda_cliente: tienda, visualizando_tienda: tienda).tap do |u|
      u.tiendas << tienda unless u.tiendas.include?(tienda)
    end
  end
  let!(:categoria) { create(:categoria, nombre: 'Test', tienda: tienda, stock_activo: false) }
  let!(:producto) { create(:producto, nombre: 'Test', tienda: tienda, categoria: categoria) }
  let!(:turno_desayuno) { create(:turno_entrega, :desayuno) }
  let!(:turno_cena) { create(:turno_entrega, codigo: 'cena', nombre: 'Cena') }

  before do
    create(:cliente_turno_entrega, cliente: cliente, turno_entrega: turno_desayuno)
    create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 50, fecha_desde: Time.zone.today)
    login_as(usuario)
  end

  def post_generar_pago_ml(pago)
    post generar_pago_ml_pedido_path(pago), xhr: true, headers: { 'Accept' => 'text/javascript' }
  end

  describe 'turno validation' do
    it 'rejects when turno is not assigned to client' do
      pedido.update_column(:turno_entrega_id, turno_cena.id)
      post_generar_pago_ml(pedido)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('mp-payment-validation-hint')
      expect(response.body).to include('no está disponible')
      expect(response.body).to include('mercadopago-button-disabled')
    end

    it 'allows turno assigned to client' do
      pedido.update_column(:turno_entrega_id, turno_desayuno.id)
      post_generar_pago_ml(pedido)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('mp-payment-validation-hint')
    end

    it 'requires turno selection for carrito_de_compras tiendas' do
      post_generar_pago_ml(pedido)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Turno de Entrega')
      expect(response.body).to include('mercadopago-button-disabled')
    end
  end

  describe 'legacy horario validation (non-carrito_de_compras tienda)' do
    let!(:legacy_tienda) do
      create(:tienda,
             nombre: 'Legacy Store',
             carrito_de_compras: false,
             venta_mostrador: true,
             horarios_de_entrega: true,
             maneja_stock: false)
    end
    let!(:legacy_local) { create(:local, tienda: legacy_tienda, nombre: 'Local LH', domicilio: 'Calle LH 123', telefono: '333') }
    let!(:legacy_cliente) do
      create(:cliente,
             tienda: legacy_tienda,
             nombre: 'Legacy Cliente',
             cuenta_corriente: false,
             horarios_de_entrega: true,
             usuario_puede_elegir_cuenta: false,
             permitir_envios_a_domicilio: true)
    end
    let!(:legacy_cuenta) { create(:cuenta, nombre: 'Cuenta Legacy', cliente: legacy_cliente, cuenta_corriente_parcial: nil) }
    let!(:legacy_usuario) do
      create(:usuario, :admin,
             cuenta: legacy_cuenta,
             tienda_cliente: legacy_tienda,
             visualizando_tienda: legacy_tienda).tap { |u| u.tiendas << legacy_tienda unless u.tiendas.include?(legacy_tienda) }
    end
    let!(:legacy_categoria) { create(:categoria, nombre: 'Drinks', tienda: legacy_tienda, stock_activo: false) }
    let!(:legacy_producto) { create(:producto, nombre: 'Agua', tienda: legacy_tienda, categoria: legacy_categoria) }
    let!(:horario) { Pedidos::Horario.create!(nombre: '10:00 - 11:00', horario: '10:00 - 11:00', tienda: legacy_tienda) }
    let!(:legacy_pedido) do
      p = build(:pedido, tienda: legacy_tienda, cuenta: legacy_cuenta, estado_id: 1,
                         fecha: Date.current + 1.day, autor: legacy_usuario, usuario: legacy_usuario,
                         venta_mostrador: true)
      p.asignar_cuenta_manual
      p.cuenta = legacy_cuenta
      p.save!
      create(:producto_solicitado, pedido: p, producto: legacy_producto, cantidad: 1, precio_unitario: 50.0)
      p
    end

    before do
      create(:precio, :for_cliente, producto: legacy_producto, cliente: legacy_cliente, importe: 50, fecha_desde: Time.zone.today)
      login_as(legacy_usuario)
    end

    it 'rejects when horario_id is missing' do
      post_generar_pago_ml(legacy_pedido)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Horario')
      expect(response.body).to include('mercadopago-button-disabled')
    end

    it 'accepts when horario_id is provided' do
      legacy_pedido.update_column(:horario_id, horario.id)
      post_generar_pago_ml(legacy_pedido)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('mp-payment-validation-hint')
    end
  end
end
