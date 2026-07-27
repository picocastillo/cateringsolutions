module Productos
  class GruposCocinasController < ApplicationController
    load_resource except: :index

    def index
      authorize! :index, GrupoCocina
      respond_to do |format|
        format.html do
          @grupos_cocinas = GrupoCocina.where(tienda_id: tienda_activa.id).order(:codigo).paginate(page: params[:page],
                                                                                                   per_page: 10)
        end
        format.json do
          @grupos_cocinas = GrupoCocina.where(tienda_id: tienda_activa.id).active.order(:codigo)
          render json: @grupos_cocinas.map { |t|
            { id: t.id, nombre: t.nombre, codigo: t.codigo, descripcion: t.descripcion }
          }
        end
      end
    end

    def new
      authorize! :new, GrupoCocina
      @grupo_cocina = GrupoCocina.new tienda: tienda_activa
      new_modal_form
    end

    def edit
      authorize! :edit, @grupo_cocina
      new_modal_form
    end

    def create
      authorize! :create, @grupo_cocina
      @grupo_cocina.save
      create_modal_form @grupo_cocina,
                        notice: "Grupo <strong>#{@grupo_cocina}</strong> creado correctamente.".html_safe
    end

    def update
      authorize! :update, @grupo_cocina
      @grupo_cocina.assign_attributes grupo_cocina_params
      @grupo_cocina.save
      create_modal_form @grupo_cocina,
                        notice: "Grupo <strong>#{@grupo_cocina}</strong> actualizada correctamente.".html_safe
    end

    def destroy
      authorize! :destroy, @grupo_cocina
      @grupo_cocina.destroy!
      create_modal_form @grupo_cocina,
                        notice: "Grupo <strong>#{@grupo_cocina}</strong> eliminado correctamente.".html_safe
    end

    def grupo_cocina_params
      params.require(:grupo_cocina).permit(:nombre, :codigo, :descripcion, :tienda_id, categoria_ids: [])
    end
  end
end
