module Productos
  class CategoriasController < ApplicationController
    load_resource except: :index

    def index
      authorize! :index, Categoria
      respond_to do |format|
        format.html do
          @categorias = Categoria.where(tienda_id: tienda_activa.id).order(:codigo).paginate(page: params[:page],
                                                                                             per_page: 10)
        end
        format.json do
          @categorias = Categoria.where(tienda_id: tienda_activa.id).active.includes(:imagenes).order(:codigo)
          render json: @categorias.map { |t|
            { id: t.id, nombre: t.nombre, codigo: t.codigo, descripcion: t.descripcion }
          }
        end
      end
    end

    def new
      authorize! :new, Categoria
      @categoria = Categoria.new tienda: tienda_activa
      new_modal_form
    end

    def edit
      authorize! :edit, @categoria
      new_modal_form
    end

    def create
      authorize! :create, @categoria
      @categoria.save
      create_modal_form @categoria,
                        notice: "Categoria <strong>#{@categoria}</strong> creado correctamente.".html_safe
    end

    def update
      authorize! :update, @categoria
      @categoria.assign_attributes categoria_params
      @categoria.save
      create_modal_form @categoria,
                        notice: "Categoria <strong>#{@categoria}</strong> actualizada correctamente.".html_safe
    end

    def destroy
      authorize! :destroy, @categoria
      @categoria.destroy!
      create_modal_form @categoria,
                        notice: "Categoria <strong>#{@categoria}</strong> eliminado correctamente.".html_safe
    end

    def categoria_params
      params.require(:categoria).permit(:nombre, :codigo, :descripcion, :menu_diario, :active, :stock_activo,
                                        :vender_en_carrito, :tienda_id)
    end
  end
end
