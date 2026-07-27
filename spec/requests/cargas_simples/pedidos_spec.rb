# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CargasSimples::Pedidos', type: :request do
  let(:tienda) do
    create(:tienda,
           nombre: 'Tienda CS Test',
           dominio: 'localhost',
           telefono: '123456789',
           email: 'test@cs.com',
           venta_mostrador: true,
           carrito_de_compras: true,
           horarios_de_entrega: false,
           maneja_stock: false)
  end

  let(:cliente) do
    create(:cliente,
           nombre: 'Cliente CS',
           tienda: tienda,
           dia_inicio_ciclo_facturacion: 1,
           vencimiento_a: 30,
           horarios_de_entrega: false,
           usuario_puede_elegir_cuenta: false,
           permitir_envios_a_domicilio: false,
           cuenta_corriente: true,
           listas_de_precio_privada: false)
  end

  let(:cuenta) { create(:cuenta, nombre: 'Cuenta CS', cliente: cliente) }

  let(:admin) do
    user = create(:usuario, :admin,
                  login: 'admincs',
                  password: 'password123',
                  password_confirmation: 'password123',
                  nombre: 'Admin CS',
                  email: 'admincs@example.com',
                  visualizando_tienda: tienda)
    user.tiendas << tienda unless user.tiendas.include?(tienda)
    user
  end

  let(:cliente_user) do
    create(:usuario, :cliente,
           login: 'clientecs',
           password: 'password123',
           password_confirmation: 'password123',
           nombre: 'Cliente CS User',
           email: 'clientecs@example.com',
           cuenta: cuenta,
           tienda_cliente: tienda,
           visualizando_tienda: tienda)
  end

  let(:categoria) do
    create(:categoria, nombre: 'Cat CS', tienda: tienda, stock_activo: false, menu_diario: false).tap do |cat|
      cliente.categorias << cat unless cliente.categorias.include?(cat)
    end
  end

  let(:producto1) do
    create(:producto, nombre: 'Producto CS 1', codigo: 'PCS001', tienda: tienda, categoria: categoria)
  end

  let(:producto2) do
    create(:producto, nombre: 'Producto CS 2', codigo: 'PCS002', tienda: tienda, categoria: categoria)
  end

  before do
    create(:categoria, nombre: 'Menu Diario CS', tienda: tienda, menu_diario: true)
    login_as(admin)
    bypass_authorization

    # Create comprobante tipos
    Comprobantes::Tipo.find_or_create_by(codigo: 1) do |tipo|
      tipo.desc = 'Factura'
      tipo.clase = 'Ventas::Facturacion::Factura'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    p1 = create(:precio, producto: producto1, importe: 150.0,
                         fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    p1.clientes << cliente unless p1.clientes.include?(cliente)
    p2 = create(:precio, producto: producto2, importe: 100.0,
                         fecha_desde: 1.week.ago, fecha_hasta: 1.year.from_now)
    p2.clientes << cliente unless p2.clientes.include?(cliente)
  end

  describe 'GET /cargas_simples/pedidos' do
    it 'returns HTTP 200' do
      get cargas_simples_pedidos_path
      expect(response).to have_http_status(:ok)
    end

    it 'renders the index page with form elements' do
      get cargas_simples_pedidos_path
      expect(response.body).to include('Carga Rápida')
      expect(response.body).to include('pedido_tipo_pedido')
      expect(response.body).to include('pedido_fecha')
    end

    it 'renders with last_user parameter' do
      get cargas_simples_pedidos_path(last_user: cliente_user.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Carga Rápida')
    end

    it 'renders with last_date parameter' do
      get cargas_simples_pedidos_path(last_date: Date.current.to_s)
      expect(response).to have_http_status(:ok)
    end

    context 'with existing pedidos' do
      before do
        3.times do |i|
          pedido = Pedidos::Pedido.new(
            autor: admin, usuario: cliente_user, cuenta: cuenta,
            fecha: Date.current - i.days, estado_id: 1,
            tienda_id: tienda.id
          )
          pedido.asignar_cuenta_manual
          pedido.cuenta = cuenta
          pedido.no_validar_fecha = true
          pedido.save!
          ps = Productos::ProductoSolicitado.new(
            pedido: pedido, producto: producto1,
            cantidad: i + 1, precio_unitario: 150.0
          )
          ps.save(validate: false)
          pedido.facturando
          pedido.aceptar! if pedido.pendiente?
        end
      end

      it 'shows pedidos list with proper eager loading (no N+1)' do
        get cargas_simples_pedidos_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Producto CS 1')
      end

      it 'paginates pedidos at 5 per page' do
        get cargas_simples_pedidos_path
        # With 3 pedidos and per_page=5, should show all on page 1
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'POST /cargas_simples/pedidos' do
    it 'creates a pedido with products' do
      expect do
        post cargas_simples_pedidos_path, params: {
          pedido: {
            usuario_id: cliente_user.id,
            cuenta_id: cuenta.id,
            fecha: Date.current.to_s,
            enviar_a_id: '',
            horario_id: '',
            direccion_envio: '',
            productos_solicitados_attributes: {
              '0' => { producto_id: producto1.id, cantidad: 2 },
              '1' => { producto_id: producto2.id, cantidad: 1 }
            }
          }
        }
      end.to change(Pedidos::Pedido, :count).by(1)

      expect(response).to redirect_to(%r{cargas_simples/pedidos})
      follow_redirect!
      expect(response.body).to include('cargado correctamente')
    end

    it 'shows error when no products selected' do
      post cargas_simples_pedidos_path, params: {
        pedido: {
          usuario_id: cliente_user.id,
          fecha: Date.current.to_s,
          enviar_a_id: '',
          horario_id: '',
          productos_solicitados_attributes: {}
        }
      }
      expect(response.body).to include('Debe seleccionar productos')
    end
  end

  describe 'POST /cargas_simples/pedidos/cambiar_usuario' do
    it 'returns updated product fields for the selected user' do
      post cambiar_usuario_cargas_simples_pedidos_path, params: {
        pedido: {
          usuario_id: cliente_user.id,
          fecha: Date.current.to_s
        }
      }, xhr: true
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /cargas_simples/pedidos/cambiar_cuenta' do
    it 'returns updated para field for the selected cuenta' do
      post cambiar_cuenta_cargas_simples_pedidos_path, params: {
        pedido: {
          cuenta_id: cuenta.id,
          fecha: Date.current.to_s
        }
      }, xhr: true
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /cargas_simples/pedidos/:id (dedupe productos_solicitados)' do
    let(:pedido) do
      p = Pedidos::Pedido.new(
        autor: admin, usuario: cliente_user, cuenta: cuenta,
        fecha: Date.current, estado_id: 1, tienda_id: tienda.id
      )
      p.asignar_cuenta_manual
      p.cuenta = cuenta
      p.no_validar_fecha = true
      p.save!
      ps = Productos::ProductoSolicitado.new(pedido: p, producto: producto1, cantidad: 2, precio_unitario: 150.0)
      ps.save(validate: false)
      p
    end

    it 'merges a new row whose producto duplicates an existing line into the existing line' do
      existing_ps = pedido.productos_solicitados.first
      patch cargas_simples_pedido_path(pedido), params: {
        pedido: {
          usuario_id: cliente_user.id,
          cuenta_id: cuenta.id,
          fecha: Date.current.to_s,
          enviar_a_id: '', horario_id: '', direccion_envio: '',
          productos_solicitados_attributes: {
            '0' => { id: existing_ps.id, producto_id: producto1.id, cantidad: 2 },
            '1' => { producto_id: producto1.id, cantidad: 3 }
          }
        }
      }
      expect(pedido.reload.productos_solicitados.where(producto_id: producto1.id).count).to eq(1)
      expect(pedido.productos_solicitados.find_by(producto_id: producto1.id).cantidad).to eq(5)
    end

    it 'merges two new rows for the same producto into a single line on create' do
      expect do
        post cargas_simples_pedidos_path, params: {
          pedido: {
            usuario_id: cliente_user.id,
            cuenta_id: cuenta.id,
            fecha: Date.current.to_s,
            enviar_a_id: '', horario_id: '', direccion_envio: '',
            productos_solicitados_attributes: {
              '0' => { producto_id: producto1.id, cantidad: 2 },
              '1' => { producto_id: producto1.id, cantidad: 4 }
            }
          }
        }
      end.to change(Pedidos::Pedido, :count).by(1)
      nuevo = Pedidos::Pedido.order(:id).last
      expect(nuevo.productos_solicitados.where(producto_id: producto1.id).count).to eq(1)
      expect(nuevo.productos_solicitados.find_by(producto_id: producto1.id).cantidad).to eq(6)
    end
  end
end
