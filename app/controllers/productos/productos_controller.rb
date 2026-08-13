module Productos
  class ProductosController < ApplicationController
    load_resource except: :index

    def index
      authorize! :index, Producto
      respond_to do |format|
        format.any :html, :js do
          @query = ProductosQuery.new query_params
          @productos = @query.page(params[:page]).per_page(10)
        end
        format.json do
          @query = ProductosQuery.new query_params.merge(busqueda: params[:q])
          render json: @query.page(params[:page]).per_page(10).to_json(only: :id, methods: [:codigo_y_nombre])
        end
      end
    end

    def menus_diarios
      authorize! :change, MenuDiario
    end

    def import
      authorize! :manage, Productos::Producto
      return unless Tiendas::HostResolver.matches?(request.host, tienda_activa.dominio) || Rails.env.development?

      import_in_background Productos::PreciosImporter
    end

    def favorito
      authorize! :create, Pedidos::Pedido
      pd = Productos::Producto.find(params[:id].to_i)
      pd&.togle_favorito(current_user)
      head :ok
    end

    def show
      @producto = Producto.includes(:categoria, precios: :clientes).find(params[:id])
      authorize! :show, @producto
      @total_cantidad_pedida = Productos::ProductoSolicitado.where(producto_id: @producto.id).sum(:cantidad)
      @total_usuarios_distintos = Productos::ProductoSolicitado.where(producto_id: @producto.id).joins(:pedido).distinct.count('pedidos.usuario_id')
    end

    def new
      authorize! :new, Producto
      @producto = Producto.new tienda_id: tienda_activa.id
      @producto.precios.build fecha_desde: Time.zone.today
    end

    def edit
      authorize! :edit, @producto
    end

    def create
      authorize! :index, @producto
      @producto.precios.clear
      @producto.assign_attributes producto_params
      if @producto.save
        redirect_to @producto, notice: "Producto #{@producto} creado correctamente."
      else
        render :new
      end
    end

    def update
      authorize! :update, @producto
      @producto.assign_attributes producto_params
      if @producto.save
        redirect_to @producto, notice: "Producto #{@producto} actualizado correctamente."
      else
        render :edit
      end
    end

    def producto_params
      params.required(:producto).permit(:nombre, :codigos_externos, :codigo, :descripcion, :precio, :active, :color,
                                        :categoria_id, :tienda_id, :mostrar_como_nuevo_hasta, :pesable,
                                        documento_ids: [],
                                        precios_attributes: [:id, :fecha_desde, :fecha_hasta, :importe,
                                                             :_destroy, { cliente_ids: [] }])
    end
  end
end
