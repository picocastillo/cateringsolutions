require 'rails_helper'

# Coverage for the MenuDiario form's tipo handling and the create flow.
#
# Background: the tienda has two visibility flags that gate which "tipos" of
# menu_diario are reachable from the form:
#   - `muestra_menus_del_dia`     → tipo `menu_diario`     (id 1)
#   - `soporta_productos_diarios` → tipo `productos_diarios` (id 2)
#
# When only one tipo is reachable, the form renders the select disabled and
# emits a sibling hidden input with the chosen tipo_id (browsers don't submit
# disabled fields). The chosen tipo_id MUST match the only tipo the tienda
# supports — otherwise validation runs against the wrong branch and surfaces
# a misleading error.
RSpec.describe 'MenusDiarios form & create flow', type: :request do
  let(:admin) do
    u = create(:usuario, :admin, visualizando_tienda: tienda)
    u.tiendas << tienda unless u.tiendas.include?(tienda)
    u
  end
  # Validation error messages embedded in the JS response have HTML entities
  # encoded twice (once by Rails, once by JS string encoding). Use a lenient
  # matcher that accepts either form.
  let(:md_only_error) { /sólo pueden ser productos de categor.as (?:&quot;|")Men. del d.a/ }
  let(:not_md_error)  { /no pueden ser productos de categor.as (?:&quot;|")Men. del d.a/ }

  let(:cat_md) { create(:categoria, nombre: 'Menu del Dia Cat', tienda: tienda, menu_diario: true,  stock_activo: false) }
  let(:cat_pd) { create(:categoria, nombre: 'Opciones Cat',     tienda: tienda, menu_diario: false, stock_activo: false) }
  let!(:prod_md1) { create(:producto, nombre: 'Combo Vegano', tienda: tienda, categoria: cat_md) }
  let!(:prod_md2) { create(:producto, nombre: 'Combo Pollo',  tienda: tienda, categoria: cat_md) }
  let!(:prod_pd1) { create(:producto, nombre: 'Galletitas Dar algarroba', tienda: tienda, categoria: cat_pd) }
  let!(:prod_pd2) { create(:producto, nombre: 'Trufas crudiveganas',      tienda: tienda, categoria: cat_pd) }

  let(:fecha) { Date.tomorrow }

  before { login_as(admin) }

  # Helper: parse the hidden input value Rails submits for tipo_id.
  # The response body is a JS string (`$('#form-modal').html("...")`) with HTML
  # quotes escaped as `\"`. We use lenient matchers that don't care about
  # quote characters.
  def tipo_id_in_form(html)
    matches = html.scan(/<input[^>]*name=\\?"menu_diario\[tipo_id\][^>]*?value=\\?"(\d+)/)
    return matches.last&.first&.to_i if matches.any?

    matches = html.scan(/<input[^>]*?value=\\?"(\d+)\\?"[^>]*name=\\?"menu_diario\[tipo_id\]/)
    matches.last&.first&.to_i
  end

  def select_disabled_for_tipo?(html)
    # Match <select ...id="menu-diario-tipo-select"...disabled... regardless of
    # whether quotes are raw (") or JS-escaped (\").
    !html.match(/<select[^>]*menu-diario-tipo-select[^>]*disabled/i).nil?
  end

  # ─── Tienda con SOLO productos_diarios habilitado ───────────────────────────
  context 'when tienda only supports productos_diarios' do
    let(:tienda) do
      create(:tienda, nombre: 'Solo Opciones', dominio: 'solo-pd.example.com',
                      muestra_menus_del_dia: false, muestra_mas_productos: false,
                      soporta_productos_diarios: true)
    end

    it 'GET /menus_diarios/new posts tipo_id = productos_diarios (regression)' do
      get '/menus_diarios/new', xhr: true
      expect(response).to have_http_status(:ok)
      expect(select_disabled_for_tipo?(response.body)).to be(true)
      expect(tipo_id_in_form(response.body)).to eq(MenusDiarios::Tipo[:productos_diarios].id)
    end

    it 'POST /menus_diarios with non-MD productos + correct tipo_id succeeds' do
      post '/menus_diarios', xhr: true, params: {
        menu_diario: {
          tienda_id: tienda.id,
          fecha: fecha.to_s,
          tipo_id: MenusDiarios::Tipo[:productos_diarios].id,
          descripcion: 'Opciones del día',
          producto_ids: [prod_pd1.id, prod_pd2.id]
        }
      }
      expect(response).to have_http_status(:ok).or have_http_status(:found)
      menu = MenusDiarios::MenuDiario.last
      expect(menu).to be_persisted
      expect(menu.tipo_id).to eq(MenusDiarios::Tipo[:productos_diarios].id)
      expect(menu.productos).to contain_exactly(prod_pd1, prod_pd2)
    end

    it 'POST with WRONG tipo_id (menu_diario) + non-MD productos triggers correct error' do
      # If somehow tipo_id=menu_diario gets submitted with non-MD productos,
      # the validation should fire the MD-branch error. This locks in the
      # validation message as a sanity check.
      post '/menus_diarios', xhr: true, params: {
        menu_diario: {
          tienda_id: tienda.id,
          fecha: fecha.to_s,
          tipo_id: MenusDiarios::Tipo[:menu_diario].id,
          descripcion: 'Bad tipo',
          producto_ids: [prod_pd1.id]
        }
      }
      menu = MenusDiarios::MenuDiario.last
      # Either no menu was persisted (validation failed) or the menu is invalid.
      # The `create` action calls `save` (not save!) and renders the modal back
      # with errors. We assert on the response body containing the error message.
      expect(response.body).to match(md_only_error)
      expect(menu).to be_nil
    end
  end

  # ─── Tienda con SOLO menu_diario habilitado ─────────────────────────────────
  context 'when tienda only supports menu_diario' do
    let(:tienda) do
      create(:tienda, nombre: 'Solo MD', dominio: 'solo-md.example.com',
                      muestra_menus_del_dia: true, muestra_mas_productos: false,
                      soporta_productos_diarios: false)
    end

    it 'GET /menus_diarios/new posts tipo_id = menu_diario' do
      get '/menus_diarios/new', xhr: true
      expect(response).to have_http_status(:ok)
      expect(select_disabled_for_tipo?(response.body)).to be(true)
      expect(tipo_id_in_form(response.body)).to eq(MenusDiarios::Tipo[:menu_diario].id)
    end

    it 'POST /menus_diarios with MD productos + correct tipo_id succeeds' do
      post '/menus_diarios', xhr: true, params: {
        menu_diario: {
          tienda_id: tienda.id,
          fecha: fecha.to_s,
          tipo_id: MenusDiarios::Tipo[:menu_diario].id,
          descripcion: 'Menú del día',
          producto_ids: [prod_md1.id, prod_md2.id]
        }
      }
      menu = MenusDiarios::MenuDiario.last
      expect(menu).to be_persisted
      expect(menu.tipo_id).to eq(MenusDiarios::Tipo[:menu_diario].id)
      expect(menu.productos).to contain_exactly(prod_md1, prod_md2)
    end

    it 'POST with non-MD productos triggers MD-branch error message' do
      post '/menus_diarios', xhr: true, params: {
        menu_diario: {
          tienda_id: tienda.id,
          fecha: fecha.to_s,
          tipo_id: MenusDiarios::Tipo[:menu_diario].id,
          descripcion: 'Bad combo',
          producto_ids: [prod_pd1.id]
        }
      }
      expect(response.body).to match(md_only_error)
    end
  end

  # ─── Tienda con AMBOS tipos habilitados ─────────────────────────────────────
  context 'when tienda supports both tipos' do
    let(:tienda) do
      create(:tienda, nombre: 'Tienda Mixta', dominio: 'mixta.example.com',
                      muestra_menus_del_dia: true, muestra_mas_productos: true,
                      soporta_productos_diarios: true)
    end

    it 'GET /menus_diarios/new renders an ENABLED select with both options' do
      get '/menus_diarios/new', xhr: true
      expect(response).to have_http_status(:ok)
      expect(select_disabled_for_tipo?(response.body)).to be(false)
      # When the select is enabled, no sibling hidden field should be emitted
      # (Rails posts the select value normally).
      expect(tipo_id_in_form(response.body)).to be_nil
      # Both options should be in the dropdown.
      expect(response.body).to include('Menú del Día')
      expect(response.body).to include('Productos del Día')
    end

    it 'POST tipo_id=menu_diario with MD productos succeeds' do
      post '/menus_diarios', xhr: true, params: {
        menu_diario: {
          tienda_id: tienda.id,
          fecha: fecha.to_s,
          tipo_id: MenusDiarios::Tipo[:menu_diario].id,
          descripcion: 'Clásico',
          producto_ids: [prod_md1.id]
        }
      }
      expect(MenusDiarios::MenuDiario.last.tipo_id).to eq(MenusDiarios::Tipo[:menu_diario].id)
    end

    it 'POST tipo_id=productos_diarios with PD productos succeeds' do
      post '/menus_diarios', xhr: true, params: {
        menu_diario: {
          tienda_id: tienda.id,
          fecha: fecha.to_s,
          tipo_id: MenusDiarios::Tipo[:productos_diarios].id,
          descripcion: 'Opciones',
          producto_ids: [prod_pd1.id, prod_pd2.id]
        }
      }
      menu = MenusDiarios::MenuDiario.last
      expect(menu.tipo_id).to eq(MenusDiarios::Tipo[:productos_diarios].id)
      expect(menu.productos).to contain_exactly(prod_pd1, prod_pd2)
    end

    it 'POST with mixed productos (MD + PD) under menu_diario tipo lists ONLY non-MD as invalid' do
      post '/menus_diarios', xhr: true, params: {
        menu_diario: {
          tienda_id: tienda.id,
          fecha: fecha.to_s,
          tipo_id: MenusDiarios::Tipo[:menu_diario].id,
          descripcion: 'Mixto',
          producto_ids: [prod_md1.id, prod_pd1.id]
        }
      }
      expect(response.body).to match(md_only_error)
      expect(response.body).to include(prod_pd1.to_s)
      expect(response.body).not_to include("Men. del d.a\": #{prod_md1}")
    end

    it 'POST with mixed productos under productos_diarios tipo lists ONLY MD as invalid' do
      post '/menus_diarios', xhr: true, params: {
        menu_diario: {
          tienda_id: tienda.id,
          fecha: fecha.to_s,
          tipo_id: MenusDiarios::Tipo[:productos_diarios].id,
          descripcion: 'Mixto al revés',
          producto_ids: [prod_md1.id, prod_pd1.id]
        }
      }
      expect(response.body).to match(not_md_error)
      expect(response.body).to include(prod_md1.to_s)
    end
  end

  # ─── Editing an existing record ─────────────────────────────────────────────
  context 'when editing an existing menu_diario' do
    let(:tienda) do
      create(:tienda, nombre: 'Edit Tienda', dominio: 'edit.example.com',
                      muestra_menus_del_dia: false, muestra_mas_productos: false,
                      soporta_productos_diarios: true)
    end

    it 'preserves persisted tipo_id even when tienda no longer supports it' do
      # Create a menu_diario tipo record in the DB directly (the tipo was supported
      # at the time of creation), then turn off muestra_menus_del_dia.
      menu = MenusDiarios::MenuDiario.new(tienda: tienda, fecha: fecha,
                                          descripcion: 'Existente',
                                          tipo_id: MenusDiarios::Tipo[:menu_diario].id,
                                          autor: admin)
      menu.productos << prod_md1
      menu.save!

      get edit_menu_diario_path(menu), xhr: true
      expect(response).to have_http_status(:ok)
      # Even though the tienda only supports productos_diarios now, the form
      # MUST render the persisted tipo_id (menu_diario) — the admin should be
      # able to keep editing the legacy record without surprise tipo changes.
      # Since only one tipo (PD) is in tipos_disponibles, the select is disabled
      # and a hidden field is emitted. With the fix, we use the persisted value.
      expect(tipo_id_in_form(response.body)).to eq(MenusDiarios::Tipo[:menu_diario].id)
    end
  end

  # ─── Calendar JSON (the surface that "made the menu disappear") ────────────
  context 'GET /menus_diarios.json (calendar feed)' do
    let(:tienda) do
      create(:tienda, nombre: 'Tivoglio Sim', dominio: 'tivoglio-sim.example.com',
                      muestra_menus_del_dia: false, muestra_mas_productos: false,
                      soporta_productos_diarios: true)
    end

    it 'renders a productos_diarios menu without raising NoMethodError on Tipo.find_by' do
      menu = MenusDiarios::MenuDiario.new(tienda: tienda, fecha: fecha,
                                          descripcion: 'Opciones del día',
                                          tipo_id: MenusDiarios::Tipo[:productos_diarios].id,
                                          autor: admin)
      menu.productos << prod_pd1
      menu.save!

      get '/menus_diarios.json'
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to be_an(Array)
      expect(body.length).to eq(1)
      expect(body.first['id']).to eq(menu.id)
      expect(body.first['className']).to include('evento-cal-productos-diarios')
      expect(body.first['backgroundColor']).to eq('#8b5cf6')
    end

    it 'renders a menu_diario menu in the calendar feed' do
      menu = MenusDiarios::MenuDiario.new(tienda: tienda, fecha: fecha,
                                          descripcion: 'Clásico',
                                          tipo_id: MenusDiarios::Tipo[:menu_diario].id,
                                          autor: admin)
      menu.productos << prod_md1
      menu.save!

      get '/menus_diarios.json'
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.length).to eq(1)
      expect(body.first['id']).to eq(menu.id)
    end
  end
end
