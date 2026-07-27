require 'rails_helper'

RSpec.describe 'Inicio stock alerts', type: :request do
  let(:tienda) do
    create(:tienda, nombre: 'Stock Futuro Store', carrito_de_compras: true, maneja_stock: true)
  end
  let(:admin) do
    create(:usuario, :admin, visualizando_tienda: tienda).tap do |usuario|
      usuario.tiendas << tienda unless usuario.tiendas.include?(tienda)
    end
  end
  let(:cliente) { create(:cliente, tienda: tienda, nombre: 'Cliente Stock Futuro') }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:categoria) { create(:categoria, tienda: tienda, nombre: 'Stock Activo', stock_activo: true) }
  let(:producto) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Producto Futuro') }

  before do
    stock = producto.stock_for_local(nil)
    stock.update!(cantidad_actual: 8, cantidad_minima: 5, activo: true)

    create(:precio, :for_cliente, producto: producto, cliente: cliente, importe: 100, fecha_desde: Time.zone.today)
    create_pedido_con_producto(estado_id: Pedidos::Estado[:aceptado].id, cantidad: 4, tienda: tienda, cuenta: cuenta, producto: producto)
    create_pedido_con_producto(estado_id: Pedidos::Estado[:pendiente].id, cantidad: 9, tienda: tienda, cuenta: cuenta, producto: producto)
    create_pedido_con_producto(estado_id: Pedidos::Estado[:confirmado].id, cantidad: 2, tienda: tienda, cuenta: cuenta, producto: producto)

    otra_tienda = create(:tienda, nombre: 'Otra Tienda', carrito_de_compras: true, maneja_stock: true)
    otro_cliente = create(:cliente, tienda: otra_tienda)
    otra_cuenta = create(:cuenta, cliente: otro_cliente)
    create_pedido_con_producto(estado_id: Pedidos::Estado[:aceptado].id, cantidad: 7, tienda: otra_tienda, cuenta: otra_cuenta, producto: producto)

    login_as(admin)
  end

  it 'shows projected stock subtracting only accepted pedidos from the active tienda' do
    get '/inicio'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Stock Comprometido por Pedidos Aceptados')
    expect(response.body).to include('Stock - Pendientes')
    expect(response.body).to include('Producto Futuro')
    expect(response.body).to include('8 - 4')
  end

  def create_pedido_con_producto(estado_id:, cantidad:, tienda:, cuenta:, producto:)
    pedido = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: Pedidos::Estado[:pendiente].id,
                            fecha: Date.current, autor: admin, usuario: admin)
    pedido.asignar_cuenta_manual
    pedido.cuenta = cuenta
    pedido.save!(validate: false)

    Productos::ProductoSolicitado.new(
      pedido: pedido,
      producto: producto,
      cantidad: cantidad,
      precio_unitario: 100,
      precio_con_descuento: 100
    ).save!(validate: false)

    pedido.update_column(:estado_id, estado_id)
    pedido
  end
end
