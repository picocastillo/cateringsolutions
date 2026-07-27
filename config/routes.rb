Rails.application.routes.draw do
  mount ActionCable.server => '/cable'

  resources :inicio, only: [:index] do
    collection do
      get :stats
      get :stats_admin
      get :analytics
      get :widget
    end
  end

  scope module: :clientes do
    resources :clientes do
      get :stats, on: :member
      get :financieros, on: :member
      get :analytics, on: :member
      get :lookup_by_cuit, on: :collection
      post :vincular_tienda, on: :member
    end
    resources :cuentas, only: :index
  end

  scope module: :tiendas do
    resources :tiendas do
      post :cambiar_tienda_activa, on: :collection
      post :cambiar_local_activo, on: :collection
    end
  end

  scope module: :locales do
    resources :locales
  end

  scope module: :cupones do
    resources :cupones do
      collection do
        delete :eliminar_grupo
        put :expirar_grupo
        put :cancelar_grupo
        get :confirmar_eliminar
        delete :eliminar_masivo
      end
    end
  end

  scope module: :productos do
    resources :productos do
      put :favorito, on: :member
      post :import, on: :collection
    end
    resources :precios, only: :index
    resources :listas_precios, only: [:index, :destroy] do
      delete :eliminar_duplicados, on: :collection
      post :import, on: :collection
    end
    resources :categorias
    resources :grupos_cocinas
    resources :etiquetas_productos
    resources :stocks do
      post :import, on: :collection
      put :ajustar_stock, on: :member
      get :movimientos, on: :member
    end
  end

  scope module: :menus_diarios do
    resources :menus_diarios do
      collection do
        get :productos_disponibles
      end
    end
  end

  scope module: :ventas do
    scope module: :facturacion do
      resources :comprobantes do
        put :confirmar, on: :member
        put :cobrar, on: :member
        put :pagar, on: :member
        post :refacturar, on: :member
        get :tomar_datos, on: :member
        get :cancelado_por, on: :member
      end
      resources :saldos, only: :index
      resources :cuentas_corrientes, only: :index
      resources :facturas, defaults: { tipo: 'factura' }, controller: :comprobantes
      resources :notas_credito, defaults: { tipo: 'nota_credito' }, controller: :comprobantes
      resources :notas_debito, defaults: { tipo: 'nota_debito' }, controller: :comprobantes
      resources :orden_pago, defaults: { tipo: 'orden_pago' }, controller: :comprobantes
    end
  end

  scope module: :cobros do
    resources :recibos, defaults: { tipo: 'recibo' }, path: 'cobros' do
      put :confirmar, on: :member
      put :continuar_afectacion, on: :member
      post :afectaciones, on: :collection
      post :afectaciones_cambio_cuenta, on: :collection
      put :anular, on: :member
    end
  end

  namespace :cargas_simples do
    resources :pedidos do
      post :cambiar_usuario, on: :collection
      post :cambiar_cuenta, on: :collection
      put :cancelar, on: :member
    end
  end

  namespace :meli do
    resources :notifications, only: :create
  end

  namespace :ventas_mostrador do
    resources :pedidos do
      post :cambiar_cuenta, on: :member
      post :limpiar, on: :member
      put :cancelar, on: :member
      post :agregar, on: :member
      post :agregar_pesable, on: :member
      post :edit, on: :member
      post :actualizar_producto, on: :member
      get :footer_aggregates, on: :collection
    end
    resources :descuentos, only: [:index, :new, :create, :edit, :update, :destroy] do
      put :toggle_activo, on: :member
    end
  end

  scope module: :pedidos do
    resources :confirmation, only: :show
    resources :horarios
    resources :pedidos do
      post :cambiar_cuenta, on: :member
      post :re_edit, on: :member
      post :actualizar_producto, on: :member
      post :actualizar_desde_carrito, on: :member
      post :cambiar_categoria, on: :member
      get :late_pannels, on: :member
      get :productos_diarios_panel, on: :member
      put :cancelar, on: :member
      post :importar, on: :collection
      get :footer_aggregates, on: :collection
      get :comprar
      # Legacy opciones route — redirected to comprar (page was merged).
      get :opciones, to: redirect { |params, _req| "/pedidos/#{params[:pedido_id]}/comprar" }
      post :finalizar, on: :member
      post :generar_pago_ml, on: :member
      post :aplicar_cupon, on: :member
      delete :quitar_cupon, on: :member
      # Multi-pedido
      post :agregar_al_multiple, on: :member
      delete :salir_del_multiple, on: :member
    end
    resources :pedidos_multiples, only: [] do
      get :resumen, on: :member
      post :generar_pago_ml_multiple, on: :member
      post :finalizar_multiple, on: :member
    end
    resources :pedidos_cocina, only: [:index, :show, :new, :create, :destroy] do
      get :find_pedidos, on: :collection
    end
    scope module: :despachos do
      resources :etiquetas, only: [:index] do
        post :importar_etiquetas_williner, on: :collection
      end
    end
  end

  scope module: :usuarios do
    resources :usuarios, except: :destroy do
      post :seleccion_rol, on: :collection
      post :import, on: :collection
      get :stats, on: :member
      post :cambiar_tienda_cliente, on: :member
    end
    resource :session, only: [:new, :create, :destroy]
    resource :cuenta, only: [:show, :edit, :update] do
      get :tipos_notificaciones
      post :actualizar_preferencias, on: :collection
      patch :cambiar_vista_productos, on: :collection
    end
  end

  get '/ayuda', to: 'inicio#ayuda'
  get '/ayuda/test_print', to: 'inicio#test_print', defaults: { format: :pdf }
  get '/qz_certificate', to: 'inicio#qz_certificate'
  post '/qz_sign', to: 'inicio#qz_sign'

  # Survey routes
  scope module: :surveys do
    resources :surveys do
      member do
        get :respond
      end
      resources :survey_responses, except: [:edit] do
        member do
          patch :complete
        end
      end
    end
  end

  scope module: :metricas do
    resources :dashboards, only: [:index], path: 'metricas'
  end

  scope module: :infraestructura do
    get '/barcode/:data', to: 'barcodes#new', as: :barcode
    resources :settings, only: [:edit, :update]
    resources :documentos, only: :create
    scope module: :procesos do
      resources :procesos, only: [:index, :destroy]
    end
  end

  resource :public, only: [:show, :create, :destroy]
  get 'manifest' => 'publics#manifest', defaults: { format: :json }
  root to: 'publics#show', via: [:get]
  get 'test_exception_tanqueta' => 'application#test_exception_tanqueta'
end
