require 'rails_helper'

# Endpoint that powers the MenuDiario form's product picker. Returns two
# catalogs (md = classic menu_diario tipo, pd = productos_diarios tipo) for a
# given fecha. The PD list must EXCLUDE productos already used by another
# productos_diarios MenuDiario on the same fecha (so the admin can't double-list
# the same producto across two opciones-del-día panels for the same day).
RSpec.describe 'GET /menus_diarios/productos_disponibles', type: :request do
  let(:tienda) { create(:tienda, nombre: 'Tienda PDispo', dominio: 'pdispo.example.com') }
  let(:admin) do
    u = create(:usuario, :admin, visualizando_tienda: tienda)
    u.tiendas << tienda unless u.tiendas.include?(tienda)
    u
  end
  let(:cat_md) { create(:categoria, nombre: 'MD Cat', tienda: tienda, menu_diario: true,  stock_activo: false) }
  let(:cat_pd) { create(:categoria, nombre: 'PD Cat', tienda: tienda, menu_diario: false, stock_activo: false) }
  let!(:prod_md)  { create(:producto, nombre: 'Combo X',  tienda: tienda, categoria: cat_md) }
  let!(:prod_pd1) { create(:producto, nombre: 'Opcion A', tienda: tienda, categoria: cat_pd) }
  let!(:prod_pd2) { create(:producto, nombre: 'Opcion B', tienda: tienda, categoria: cat_pd) }
  let!(:prod_pd3) { create(:producto, nombre: 'Opcion C', tienda: tienda, categoria: cat_pd) }
  let(:fecha) { Date.tomorrow }

  before { login_as(admin) }

  it 'returns both catalogs split by tipo' do
    get '/menus_diarios/productos_disponibles', params: { fecha: fecha.to_s }
    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    md_ids = body['md'].pluck('id')
    pd_ids = body['pd'].pluck('id')
    expect(md_ids).to contain_exactly(prod_md.id)
    expect(pd_ids).to contain_exactly(prod_pd1.id, prod_pd2.id, prod_pd3.id)
  end

  it 'excludes productos already used by another productos_diarios menu on the same fecha' do
    MenusDiarios::MenuDiario.create!(productos: [prod_pd1, prod_pd2], fecha: fecha,
                                     descripcion: 'Existente', tienda: tienda, autor: admin,
                                     tipo_id: MenusDiarios::Tipo[:productos_diarios].id)

    get '/menus_diarios/productos_disponibles', params: { fecha: fecha.to_s }
    body = response.parsed_body
    expect(body['pd'].pluck('id')).to contain_exactly(prod_pd3.id)
  end

  it 'still includes productos used by the menu being edited (exclude_id)' do
    md = MenusDiarios::MenuDiario.create!(productos: [prod_pd1], fecha: fecha,
                                          descripcion: 'En edicion', tienda: tienda, autor: admin,
                                          tipo_id: MenusDiarios::Tipo[:productos_diarios].id)

    get '/menus_diarios/productos_disponibles', params: { fecha: fecha.to_s, exclude_id: md.id }
    body = response.parsed_body
    expect(body['pd'].pluck('id')).to include(prod_pd1.id)
  end

  it 'does NOT exclude productos used by classic menu_diario tipo on the same fecha' do
    # A menu_diario tipo containing the producto must NOT shrink the PD pool —
    # only PD-tipo menus reserve productos for opciones del día.
    md_clasico = MenusDiarios::MenuDiario.new(fecha: fecha, descripcion: 'Clasico', tienda: tienda,
                                              autor: admin, tipo_id: MenusDiarios::Tipo[:menu_diario].id)
    md_clasico.productos << prod_md
    md_clasico.save!

    get '/menus_diarios/productos_disponibles', params: { fecha: fecha.to_s }
    body = response.parsed_body
    expect(body['pd'].pluck('id')).to contain_exactly(prod_pd1.id, prod_pd2.id, prod_pd3.id)
  end

  it 'returns empty arrays when fecha is missing or unparseable' do
    get '/menus_diarios/productos_disponibles'
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('pd' => [], 'md' => [])
  end
end
