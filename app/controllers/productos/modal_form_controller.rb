module Productos
  class ModalFormController < ApplicationController
    class_attribute :categoria

    def new
      @categoria = Categoria.new params[:categoria]
      renders modal_form / new
    end

    def create
      @categoria = Categoria.new params[:categoria]
      authorize! rol_requerido, @categoria
      renders modal_form / create
    end
  end
end
