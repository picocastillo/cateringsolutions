require 'rails_helper'

RSpec.describe 'generar_pedidos_a_cocinar', type: :request do
  let(:tienda) { create(:tienda, carrito_de_compras: true) }
  let(:cliente) { create(:cliente, tienda: tienda, horario_corte_pedidos: '14:00') }
  let(:cuenta) { create(:cuenta, cliente: cliente) }
  let(:admin_user) do
    user = create(:usuario, :admin, visualizando_tienda: tienda)
    user.tiendas << tienda unless user.tiendas.include?(tienda)
    user
  end

  def create_pedido_at_estado(estado_id, pedido_cocina_id: nil, fecha: Date.current)
    pedido = Pedidos::Pedido.new(
      tienda: tienda, cuenta: cuenta, fecha: fecha,
      estado_id: 1, autor: admin_user, usuario: admin_user
    )
    pedido.save(validate: false)
    prod = create(:producto, tienda: tienda, categoria: create(:categoria, tienda: tienda))
    Productos::ProductoSolicitado.new(pedido: pedido, producto: prod, cantidad: 1, precio_unitario: 100).save(validate: false)
    pedido.update_columns(estado_id: estado_id, pedido_cocina_id: pedido_cocina_id)
    pedido
  end

  describe 'counter values are correct' do
    before do
      login_as(admin_user)
      bypass_authorization

      # Create pedidos at various estados for today
      @pedido_aceptado1 = create_pedido_at_estado(2) # pendientes (aceptado, no cocina)
      @pedido_aceptado2 = create_pedido_at_estado(2)
      @pedido_confirmado_no_cocina = create_pedido_at_estado(3) # listos_cocinar
      @pedido_confirmado_cocinado = create_pedido_at_estado(3, pedido_cocina_id: 999) # cocinados
      @pedido_pendiente = create_pedido_at_estado(1) # not counted
      @pedido_cancelado = create_pedido_at_estado(5) # not counted
      @pedido_yesterday = create_pedido_at_estado(2, fecha: 1.day.ago) # not counted (wrong date)
    end

    it 'computes total_pedidos_hoy correctly (excludes estado 1, 4, 5)' do
      get '/inicio'
      expect(assigns(:total_pedidos_hoy)).to eq(4) # 2 aceptado + 1 confirmado no cocina + 1 confirmado cocinado
    end

    it 'computes pedidos_pendientes correctly (estado 2, no cocina)' do
      get '/inicio'
      expect(assigns(:pedidos_pendientes)).to eq(2) # 2 aceptado with pedido_cocina_id nil
    end

    it 'computes pedidos_listos_cocinar correctly (estado 3, no cocina)' do
      get '/inicio'
      expect(assigns(:pedidos_listos_cocinar)).to eq(1) # 1 confirmado with pedido_cocina_id nil
    end

    it 'computes pedidos_cocinados correctly (estado 3, with cocina)' do
      get '/inicio'
      expect(assigns(:pedidos_cocinados)).to eq(1) # 1 confirmado with pedido_cocina_id set
    end

    it 'computes pedidos_pendientes_cortes correctly' do
      get '/inicio'
      expect(assigns(:pedidos_pendientes_cortes)).to be_an(Array)
      expect(assigns(:pedidos_pendientes_cortes)).to include('14:00')
    end

    it 'excludes venta_mostrador pedidos from counters' do
      vm_pedido = create_pedido_at_estado(2) # would be counted as pendiente
      vm_pedido.update_column(:venta_mostrador, true)

      get '/inicio'
      # Only 2 aceptado (non-VM) should count as pendientes
      expect(assigns(:pedidos_pendientes)).to eq(2)
      # Total should remain 4 (the VM pedido is excluded)
      expect(assigns(:total_pedidos_hoy)).to eq(4)
    end
  end
end
