module MenusDiarios
  class ModalFormController < ApplicationController
    class_attribute :menu_diario

    def new
      @menu_diario = MenuDiario.new params[:menu_diario]
      renders modal_form / new
    end

    def create
      @menu_diario = MenuDiario.new params[:menu_diario]
      authorize! rol_requerido, @menu_diario
      renders modal_form / create
    end
  end
end
