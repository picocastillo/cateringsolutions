module Locales
  class LocalesController < ApplicationController
    load_and_authorize_resource except: [:index, :new]

    def index
      authorize! :index, Local
      respond_to do |format|
        format.any :html do
          @locales = Locales::Local.where(tienda_id: tienda_activa.id).paginate(page: params[:page], per_page: 10)
        end
      end
    end

    def new
      @local = Local.new
      authorize! :new, @local
      new_modal_form
    end

    def edit
      authorize! :edit, @local
      new_modal_form
    end

    def create
      authorize! :create, @local
      @local.tienda_id = tienda_activa.id
      @local.save
      create_modal_form @local, notice: "Local <strong>#{@local}</strong> creado correctamente.".html_safe
    end

    def update
      authorize! :update, @local
      @local.assign_attributes local_params
      @local.save
      create_modal_form @local, notice: "Local <strong>#{@local}</strong> actualizado correctamente.".html_safe
    end

    def local_params
      params.require(:local).permit(:nombre, :domicilio, :telefono, documento_ids: [])
    end
  end
end
