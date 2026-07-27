module Infraestructura
  class DocumentosController < ApplicationController
    def create
      authorize! :create, Documento
      @documento = Documento.create documento: params[:file], autor: current_user
    end
  end
end
