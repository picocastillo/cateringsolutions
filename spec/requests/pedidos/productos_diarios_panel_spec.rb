require 'rails_helper'

# Lazy-load endpoint for the "Nuestras opciones del día" panel. The pedido edit
# page renders a spinner placeholder; once mounted, JS calls this endpoint to
# fetch the rendered HTML for the productos_diarios MenuDiarios on the pedido
# fecha.
RSpec.describe 'GET /pedidos/:id/productos_diarios_panel', type: :request do
  let(:tienda) do
    create(:tienda, nombre: 'Tienda PDpanel', dominio: 'pdpanel.example.com',
                    soporta_productos_diarios: true, carrito_de_compras: true)
  end
  let(:cliente)  { create(:cliente, tienda: tienda, nombre: 'Cli PDpanel') }
  let(:cuenta)   { create(:cuenta, cliente: cliente, nombre: 'Cuenta PDpanel') }
  let(:admin) do
    u = create(:usuario, :admin, visualizando_tienda: tienda)
    u.tiendas << tienda unless u.tiendas.include?(tienda)
    u
  end
  let(:cat_pd) { create(:categoria, nombre: 'Diarios', tienda: tienda, menu_diario: false, stock_activo: false) }
  let(:prod_pd) { create(:producto, nombre: 'Opcion del día', tienda: tienda, categoria: cat_pd) }
  let(:fecha) { cuenta.proximo_dia_pedido }
  let(:pedido) do
    p = build(:pedido, tienda: tienda, cuenta: cuenta, estado_id: 1, fecha: fecha,
                       autor: admin, usuario: admin)
    p.asignar_cuenta_manual
    p.cuenta = cuenta
    p.save!
    p
  end

  before do
    create(:precio, :for_cliente, producto: prod_pd, cliente: cliente, importe: 200, fecha_desde: Time.zone.today - 1)
    login_as(admin)
  end

  it 'renders the panel JS template with the productos_diarios menu content' do
    MenusDiarios::MenuDiario.create!(productos: [prod_pd], fecha: fecha,
                                     descripcion: 'Plato del Día', tienda: tienda,
                                     autor: admin,
                                     tipo_id: MenusDiarios::Tipo[:productos_diarios].id)

    get "/pedidos/#{pedido.id}/productos_diarios_panel", xhr: true,
                                                         headers: { 'Accept' => 'text/javascript' }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/javascript')
    expect(response.body).to include('opciones-del-dia-loader')
    expect(response.body).to include('Plato del Día')
    expect(response.body).to include('initProductSliders')
  end

  it 'renders an empty panel (no section) when there are no productos_diarios menus' do
    get "/pedidos/#{pedido.id}/productos_diarios_panel", xhr: true,
                                                         headers: { 'Accept' => 'text/javascript' }

    expect(response).to have_http_status(:ok)
    # The partial returns no #opciones-del-dia-section when the helper yields []
    expect(response.body).not_to include('opciones-del-dia-title')
  end
end
