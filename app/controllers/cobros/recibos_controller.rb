module Cobros
  class RecibosController < ApplicationController
    load_resource except: :index

    def index
      authorize!(:index, Recibo)
      @query = Cobros::RecibosQuery.new query_params.reverse_merge(emitidos_desde: Time.zone.today, estado_id: 2)
      @recibos = @query.includes(:afectados).page(params[:page]).per_page(10)
    end

    def show
      authorize!(:read, Recibo)
      @recibo = Recibo.find(params[:id])
      respond_to do |wants|
        wants.html
        wants.pdf do
          @a_imprimir = [@recibo]
          render_pdf
        end
      end
    end

    def new
      @recibo = Recibo.new tienda: tienda_activa
      authorize!(:change, @recibo)
      Cobros::Recibo::MediosPago.each do |medio|
        @recibo.try(medio).build importe: 0
      end
    end

    def edit
      authorize!(:change, Recibo)
    end

    def anular
      recibo = Recibo.find(params[:id])
      authorize!(:change, recibo)
      recibo.anular current_user
      if recibo.save!
        redirect_to :back, notice: "#{recibo} anulado correctamente."
      else
        redirect_to :back, flash: { error: "Error al anular #{recibo}." }
      end
    end

    def create
      authorize! :change, @recibo
      if @recibo.save
        redirect_to recibo_path(@recibo), notice: "#{@recibo} Creado."
      else
        render :new
      end
    end

    def update
      authorize! :change, @recibo
      if @recibo.save
        redirect_to recibo_path(@recibo), notice: "#{@recibo} actualizado."
      else
        render :edit
      end
    end

    def continuar_afectacion
      authorize! :change, @recibo
      @continuando_afectacion = params[:cobros_recibo][:continuando_afectacion].present?
      params[:cobros_recibo].delete(:continuando_afectacion)
      @recibo.attributes = params[:cobros_recibo]
      @recibo.continuar_afectacion current_user
      if @recibo.save
        redirect_to @recibo, notice: "#{@recibo} actualizado."
      else
        render :edit
      end
    end

    def confirmar
      authorize! :confirmar, @recibo
      if @recibo.confirmar(current_user).save
        redirect_to recibo_path(@recibo), notice: "#{@recibo} #{@recibo.estado}."
      else
        flash.now[:error] = @recibo.errors.full_messages
        render :show
      end
    end
    transaction :confirmar

    def afectaciones
      @recibo ||= Recibo.new tienda: tienda_activa
      authorize! :change, @recibo
      @recibo.attributes = recibo_params
      @recibo.preparar_afectaciones
    end

    def afectaciones_cambio_cuenta
      @recibo ||= Recibo.new tienda: tienda_activa
      authorize! :change, @recibo
      @recibo.attributes = recibo_params
      @recibo.afectaciones = []
      @recibo.preparar_afectaciones
    end

    private

    def recibo_params
      params.require(:recibo).permit(:id, :cuenta_id, :tienda_id, :fecha_emision, :documento_field_name,
                                     documento_ids: [],
                                     efectivos_attributes: [:id, :importe, :_destroy],
                                     debitos_attributes: [:id, :importe, :_destroy],
                                     creditos_attributes: [:id, :importe, :_destroy],
                                     qrs_attributes: [:id, :importe, :_destroy],
                                     transferencias_attributes: [:id, :importe, :_destroy],
                                     retenciones_attributes: [:id, :fecha_retencion, :importe, :_destroy],
                                     afectaciones_attributes: [:id, :afectado_id, :importe, :_destroy])
            .merge(autor: current_user)
    end
  end
end
