# Request Spec: cambiar_cuenta preserves cuenta when tipo_pedido=2 and usuario_id is blank
#
# Bug: when JS fires cambiar_cuenta (e.g. from a fecha or cuenta change event) for a
# cuenta-only pedido (pedido_para_empresa=true), the form always includes usuario_id=""
# because there is no selected user.  The controller's elsif branch ran:
#
#   elsif pedido_params.key?(:usuario_id)
#     @pedido.usuario = nil
#     @pedido.cuenta  = nil   # ← cleared cuenta even in Cuenta mode
#   end
#
# This saved pedido_para_empresa=false to the DB.  On the next page load, the
# "Para" selector showed "Usuario" instead of "Cuenta".
#
# Fix: only clear the cuenta when tipo_pedido=1 (Usuario mode).
# In Cuenta mode (tipo_pedido=2) a blank usuario_id is expected and must be ignored.

require 'rails_helper'

RSpec.describe 'cambiar_cuenta — preserva Cuenta mode', type: :request do
  let!(:tienda) { create(:tienda, nombre: 'CC Test Store', carrito_de_compras: true) }
  let!(:admin_user) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let!(:cliente) do
    create(:cliente, tienda: tienda, nombre: 'CC Cliente',
                     cuenta_corriente: true,
                     horarios_de_entrega: false,
                     usuario_puede_elegir_cuenta: false,
                     permitir_envios_a_domicilio: false)
  end
  let!(:cuenta) { create(:cuenta, nombre: 'CC Cuenta', cliente: cliente, cuenta_corriente_parcial: true) }

  let(:valid_fecha) { (Date.current + 1).to_s }

  let(:pedido) do
    p = build(:pedido,
              tienda: tienda,
              cuenta: cuenta,
              usuario: nil,
              estado_id: 1,
              fecha: Date.current + 1,
              autor: admin_user,
              pedido_para_empresa: true)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    p
  end

  before do
    admin_user.tiendas << tienda unless admin_user.tiendas.include?(tienda)
    login_as(admin_user)
  end

  describe 'POST cambiar_cuenta' do
    context 'con tipo_pedido=2 (Cuenta) y usuario_id en blanco' do
      it 'no borra pedido_para_empresa ni cuenta_id de la base de datos' do
        # This is the exact payload the JS sends when a fecha or cuenta change fires
        # cambiar_cuenta while the form is in Cuenta mode
        post cambiar_cuenta_pedido_path(pedido),
             params: {
               pedido: {
                 tipo_pedido: '2',
                 usuario_id: '',
                 cuenta_id: cuenta.id.to_s,
                 fecha: valid_fecha
               }
             },
             headers: { 'Accept' => 'text/javascript, application/javascript' }

        pedido.reload
        expect(pedido.pedido_para_empresa).to be(true),
                                              "cambiar_cuenta borró pedido_para_empresa (ahora #{pedido.pedido_para_empresa.inspect})"
        expect(pedido.cuenta_id).to eq(cuenta.id),
                                    "cambiar_cuenta borró cuenta_id (ahora #{pedido.cuenta_id.inspect})"
      end
    end

    context 'con tipo_pedido=1 (Usuario) y usuario_id en blanco' do
      it 'sí borra usuario y cuenta — comportamiento esperado al deseleccionar usuario' do
        # A pedido with a user that gets cleared (user is removed)
        usuario_cliente = create(:usuario, :cliente,
                                 login: 'cc_cliente_user',
                                 password: 'password123',
                                 password_confirmation: 'password123',
                                 nombre: 'CC User',
                                 email: 'cc@test.com',
                                 cuenta: cuenta,
                                 tienda_cliente: tienda,
                                 visualizando_tienda: tienda)
        pedido_usuario = build(:pedido,
                               tienda: tienda,
                               cuenta: cuenta,
                               usuario: usuario_cliente,
                               estado_id: 1,
                               fecha: Date.current + 1,
                               autor: admin_user,
                               pedido_para_empresa: false)
        pedido_usuario.asignar_cuenta_manual
        pedido_usuario.cuenta = cuenta
        pedido_usuario.save!

        post cambiar_cuenta_pedido_path(pedido_usuario),
             params: {
               pedido: {
                 tipo_pedido: '1',
                 usuario_id: '',
                 cuenta_id: '',
                 fecha: valid_fecha
               }
             },
             headers: { 'Accept' => 'text/javascript, application/javascript' }

        pedido_usuario.reload
        expect(pedido_usuario.usuario_id).to be_nil
        expect(pedido_usuario.cuenta_id).to be_nil
      end
    end
  end
end
