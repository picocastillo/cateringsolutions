require 'rails_helper'

RSpec.describe 'Productos::ListasPrecios', type: :request do
  let(:tienda) { create(:tienda, nombre: 'Test Store') }
  let(:admin_user) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let(:categoria) { create(:categoria, tienda: tienda) }
  let(:producto) { create(:producto, tienda: tienda, categoria: categoria) }
  let(:cliente) { create(:cliente, tienda: tienda) }

  before do
    admin_user.tiendas << tienda unless admin_user.tiendas.include?(tienda)
    login_as(admin_user)
  end

  describe 'GET /listas_precios' do
    it 'returns http success' do
      get '/listas_precios'
      expect(response).to have_http_status(:success)
    end

    it 'displays precios' do
      create(:precio, producto: producto, importe: 250.0)
      get '/listas_precios'
      expect(response.body).to include(producto.nombre)
    end

    it 'filters by cliente' do
      create(:precio, producto: producto, importe: 100.0)
      create(:precio, :for_cliente, producto: producto, importe: 200.0, cliente: cliente)

      get '/listas_precios', params: { q: { clientes_ids: [cliente.id] } }
      expect(response).to have_http_status(:success)
    end

    it 'filters by categoria' do
      otra_cat = create(:categoria, tienda: tienda, nombre: 'Otra')
      otro_prod = create(:producto, tienda: tienda, categoria: otra_cat)
      create(:precio, producto: producto, importe: 100.0)
      create(:precio, producto: otro_prod, importe: 200.0)

      get '/listas_precios', params: { q: { categoria_ids: [categoria.id] } }
      expect(response.body).to include(producto.nombre)
      expect(response.body).not_to include(otro_prod.nombre)
    end

    it 'filters by nombre_producto' do
      create(:precio, producto: producto, importe: 100.0)
      get '/listas_precios', params: { q: { nombre_producto: producto.nombre } }
      expect(response.body).to include(producto.nombre)
    end

    it 'responds to JS format' do
      get '/listas_precios', params: { q: {} }, as: :js
      expect(response).to have_http_status(:success)
    end

    it 'shows duplicate indicators' do
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      get '/listas_precios', params: { q: { solo_duplicados: 'true' } }
      expect(response).to have_http_status(:success)
    end

    context 'productos sin precio filter' do
      let(:producto_sin_precio) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Sin Precio') }
      let(:producto_con_precio) { create(:producto, tienda: tienda, categoria: categoria, nombre: 'Con Precio') }

      before do
        producto_sin_precio # create it
        create(:precio, producto: producto_con_precio, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 1.year)
      end

      it 'shows products without active precio' do
        get '/listas_precios', params: { q: { productos_sin_precio: 'true' } }
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Sin Precio')
        expect(response.body).not_to include('Con Precio')
      end

      it 'filters by categoria' do
        otra_cat = create(:categoria, tienda: tienda, nombre: 'Otra')
        create(:producto, tienda: tienda, categoria: otra_cat, nombre: 'Otra Cat Sin Precio')

        get '/listas_precios', params: { q: { productos_sin_precio: 'true', categoria_ids: [categoria.id] } }
        expect(response.body).to include('Sin Precio')
        expect(response.body).not_to include('Otra Cat Sin Precio')
      end

      it 'filters by nombre_producto' do
        create(:producto, tienda: tienda, categoria: categoria, nombre: 'Otro Sin Precio')

        get '/listas_precios', params: { q: { productos_sin_precio: 'true', nombre_producto: 'Otro' } }
        expect(response.body).to include('Otro Sin Precio')
        expect(response.body).not_to include('>Sin Precio<')
      end

      it 'considers activo_el date for active precios' do
        # producto has a precio that starts tomorrow — so today it has no precio
        prod_futuro = create(:producto, tienda: tienda, categoria: categoria, nombre: 'Futuro Precio')
        create(:precio, producto: prod_futuro, importe: 50.0, fecha_desde: Date.current + 1, fecha_hasta: Date.current + 1.year)

        get '/listas_precios', params: { q: { productos_sin_precio: 'true', activo_el: Date.current.strftime('%d/%m/%Y') } }
        expect(response.body).to include('Futuro Precio')
      end

      it 'does not show products from other tiendas' do
        otra_tienda = create(:tienda, nombre: 'Otra Tienda')
        otra_cat = create(:categoria, tienda: otra_tienda)
        create(:producto, tienda: otra_tienda, categoria: otra_cat, nombre: 'Ajeno Sin Precio')

        get '/listas_precios', params: { q: { productos_sin_precio: 'true' } }
        expect(response.body).not_to include('Ajeno Sin Precio')
      end

      it 'does not show discontinued products' do
        prod_disc = create(:producto, tienda: tienda, categoria: categoria, nombre: 'Discontinuado')
        prod_disc.discontinue!

        get '/listas_precios', params: { q: { productos_sin_precio: 'true' } }
        expect(response.body).not_to include('Discontinuado')
      end

      it 'shows different table columns for sin precio mode' do
        get '/listas_precios', params: { q: { productos_sin_precio: 'true' } }
        expect(response.body).to include('<th>Código</th>')
        expect(response.body).not_to include('<th class="text-right">Importe</th>')
      end
    end
  end

  describe 'DELETE /listas_precios/:id' do
    it 'deletes the precio' do
      precio = create(:precio, producto: producto, importe: 100.0)
      expect do
        delete "/listas_precios/#{precio.id}"
      end.to change(Productos::Precio, :count).by(-1)
      expect(response).to redirect_to(listas_precios_path)
    end

    it 'sets flash notice' do
      precio = create(:precio, producto: producto, importe: 100.0)
      delete "/listas_precios/#{precio.id}"
      expect(flash[:notice]).to eq('Precio eliminado correctamente.')
    end

    it 'prevents deleting precios from other tiendas' do
      otra_tienda = create(:tienda, nombre: 'Otra Tienda')
      otra_cat = create(:categoria, tienda: otra_tienda)
      otro_producto = create(:producto, tienda: otra_tienda, categoria: otra_cat)
      precio = create(:precio, producto: otro_producto, importe: 100.0)

      expect do
        delete "/listas_precios/#{precio.id}"
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /listas_precios/eliminar_duplicados' do
    it 'removes duplicate precios with same importe' do
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)

      expect do
        delete '/listas_precios/eliminar_duplicados'
      end.to change(Productos::Precio, :count).by(-1)
    end

    it 'keeps the most recently updated precio' do
      old_precio = create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      old_precio.update_column(:updated_at, 1.day.ago)
      new_precio = create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)

      delete '/listas_precios/eliminar_duplicados'
      expect(Productos::Precio.exists?(new_precio.id)).to be true
      expect(Productos::Precio.exists?(old_precio.id)).to be false
    end

    it 'does not remove precios with different importes' do
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      create(:precio, producto: producto, importe: 200.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)

      expect do
        delete '/listas_precios/eliminar_duplicados'
      end.not_to change(Productos::Precio, :count)
    end

    it 'does not remove precios with different dates' do
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current + 1, fecha_hasta: Date.current + 31)

      expect do
        delete '/listas_precios/eliminar_duplicados'
      end.not_to change(Productos::Precio, :count)
    end

    it 'does not remove precios with different clients' do
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      create(:precio, :for_cliente, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30, cliente: cliente)

      expect do
        delete '/listas_precios/eliminar_duplicados'
      end.not_to change(Productos::Precio, :count)
    end

    # Regression: previously the action loaded precios via `base_scope.includes(:clientes)`,
    # but `base_scope` has `.group('precios.id')` + a LEFT JOIN to `clientes_precios`,
    # which made the eager-loaded `clientes` collection come back empty. Universal precios
    # and client-specific precios with the same producto/importe/fechas were grouped
    # together and the older one (often the cliente-specific) was deleted, leaving the
    # cliente without a price.
    it 'does NOT collapse universal precio with cliente-specific precio (regression)' do
      cliente_a = create(:cliente, tienda: tienda, nombre: 'Cliente A')
      cliente_b = create(:cliente, tienda: tienda, nombre: 'Cliente B')

      universal = create(:precio, producto: producto, importe: 100.0,
                                  fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      precio_a  = create(:precio, :for_cliente, producto: producto, importe: 100.0,
                                                fecha_desde: Date.current, fecha_hasta: Date.current + 30,
                                                cliente: cliente_a)
      precio_b  = create(:precio, :for_cliente, producto: producto, importe: 100.0,
                                                fecha_desde: Date.current, fecha_hasta: Date.current + 30,
                                                cliente: cliente_b)

      # Make universal the oldest so the buggy code would target it for deletion
      # (and along with it the cliente-specific ones it wrongly grouped with).
      universal.update_column(:updated_at, 3.days.ago)
      precio_a.update_column(:updated_at, 2.days.ago)
      precio_b.update_column(:updated_at, 1.day.ago)

      expect do
        delete '/listas_precios/eliminar_duplicados'
      end.not_to change(Productos::Precio, :count)

      expect(Productos::Precio.exists?(universal.id)).to be true
      expect(Productos::Precio.exists?(precio_a.id)).to be true
      expect(Productos::Precio.exists?(precio_b.id)).to be true
    end

    it 'cleans up clientes_precios join rows when deleting duplicates (uses destroy_all not delete_all)' do
      old_precio = create(:precio, :for_cliente, producto: producto, importe: 100.0,
                                                 fecha_desde: Date.current, fecha_hasta: Date.current + 30,
                                                 cliente: cliente)
      old_precio.update_column(:updated_at, 1.day.ago)
      new_precio = create(:precio, :for_cliente, producto: producto, importe: 100.0,
                                                 fecha_desde: Date.current, fecha_hasta: Date.current + 30,
                                                 cliente: cliente)

      delete '/listas_precios/eliminar_duplicados'

      expect(Productos::Precio.exists?(old_precio.id)).to be false
      # No orphan join row remains for the deleted precio
      orphans = ActiveRecord::Base.connection.select_value(
        "SELECT COUNT(*) FROM clientes_precios WHERE precio_id = #{old_precio.id}"
      )
      expect(orphans).to eq(0)
      expect(new_precio.reload.clientes).to include(cliente)
    end

    it 'skips already-discontinued precios' do
      keep = create(:precio, producto: producto, importe: 100.0,
                             fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      disc = create(:precio, producto: producto, importe: 100.0,
                             fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      disc.discontinue!

      expect do
        delete '/listas_precios/eliminar_duplicados'
      end.not_to change(Productos::Precio, :count)

      expect(Productos::Precio.exists?(keep.id)).to be true
    end

    it 'respects filters when eliminating duplicates' do
      otra_cat = create(:categoria, tienda: tienda, nombre: 'Otra')
      otro_prod = create(:producto, tienda: tienda, categoria: otra_cat)

      # Duplicates in filtered category
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)

      # Duplicates in other category
      create(:precio, producto: otro_prod, importe: 200.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      create(:precio, producto: otro_prod, importe: 200.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)

      expect do
        delete '/listas_precios/eliminar_duplicados', params: { q: { categoria_ids: [categoria.id] } }
      end.to change(Productos::Precio, :count).by(-1)
      # Only duplicates in the filtered category should be removed
      expect(Productos::Precio.where(producto: otro_prod).count).to eq(2)
    end

    it 'shows flash when no duplicates found' do
      create(:precio, producto: producto, importe: 100.0)
      delete '/listas_precios/eliminar_duplicados'
      expect(flash[:notice]).to include('No se encontraron')
    end

    it 'shows flash with count when duplicates deleted' do
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)
      create(:precio, producto: producto, importe: 100.0, fecha_desde: Date.current, fecha_hasta: Date.current + 30)

      delete '/listas_precios/eliminar_duplicados'
      expect(flash[:notice]).to include('Se eliminaron 2')
    end

    it 'redirects to listas_precios_path' do
      delete '/listas_precios/eliminar_duplicados'
      expect(response).to redirect_to(listas_precios_path)
    end
  end

  describe 'POST /listas_precios/import' do
    it 'redirects to procesos path on success' do
      file = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/precios_import.xlsx'), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      proceso = instance_double(Productos::PreciosImporter, save: true, errors: double(full_messages: []))
      allow(Productos::PreciosImporter).to receive(:new).and_return(proceso)
      allow(Infraestructura::Procesos::LanzarProcesoJob).to receive(:perform_later)

      post '/listas_precios/import', params: { proceso: { adjunto: file } }
      expect(response).to redirect_to(procesos_path)
      expect(flash[:notice]).to include('importará en breve')
    end

    it 'shows error when proceso is invalid' do
      file = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/precios_import.xlsx'), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      proceso = instance_double(Productos::PreciosImporter, save: false, errors: double(full_messages: ['Adjunto inválido']))
      allow(Productos::PreciosImporter).to receive(:new).and_return(proceso)

      post '/listas_precios/import', params: { proceso: { adjunto: file } }
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'GET /listas_precios.xls (export)' do
    it 'redirects to procesos path for background export' do
      create(:precio, producto: producto, importe: 100.0)
      exporter = instance_double(Productos::PreciosExporter)
      allow(Productos::PreciosExporter).to receive(:create).and_return(exporter)
      allow(Infraestructura::Procesos::LanzarProcesoJob).to receive(:perform_later)

      get '/listas_precios.xls'
      expect(response).to redirect_to(procesos_path)
      expect(flash[:notice]).to include('planilla se generará')
    end

    it 'passes filtered params to exporter' do
      create(:precio, producto: producto, importe: 100.0)
      expect(Productos::PreciosExporter).to receive(:create).with(
        hash_including(autor: admin_user, tienda: tienda)
      ).and_return(instance_double(Productos::PreciosExporter))
      allow(Infraestructura::Procesos::LanzarProcesoJob).to receive(:perform_later)

      get '/listas_precios.xls', params: { q: { nombre_producto: 'test' } }
      expect(response).to redirect_to(procesos_path)
    end
  end
end
