module Cupones
  class CuponesController < ApplicationController
    load_resource except: [:index, :create, :expirar_grupo, :eliminar_grupo, :cancelar_grupo, :confirmar_eliminar, :eliminar_masivo]

    def index
      authorize! :index, Cupon
      @query = Cupones::CuponesQuery.new query_params
      @cupones = @query.page(params[:page]).per_page(10)
      respond_to do |format|
        format.html
        format.js
        format.pdf do
  @cupones = @query.run
  render_pdf silent_print: true
end
      end
    end

    def show
      authorize! :read, @cupon
      respond_to do |format|
        format.pdf { render_pdf silent_print: true }
      end
    end

    def new
      authorize! :new, Cupon
      @cupon = Cupon.new(tienda: tienda_activa)
      new_modal_form
    end

    def edit
      authorize! :edit, @cupon
      new_modal_form
    end

    def create
      authorize! :create, Cupon
      attrs = cupon_params.merge(tienda_id: tienda_activa.id)

      cupones = crear_cupones(attrs)

      if cupones.any?(&:persisted?)
        cantidad = cupones.count(&:persisted?)
        @cupon = cupones.first
        create_modal_form @cupon,
                          notice: "#{cantidad} #{'cupón'.pluralize(cantidad)} creado#{if cantidad > 1
                                                                                        's'
                                                                                      end} correctamente (grupo #{@cupon.grupo.first(8)}).".html_safe
      else
        @cupon = cupones.first || Cupon.new(attrs)
        render_modal_form_with_errors
      end
    end

    def update
      authorize! :update, @cupon
      @cupon.assign_attributes cupon_params
      @cupon.save
      create_modal_form @cupon,
                        notice: "Cupón <strong>#{@cupon}</strong> actualizado correctamente.".html_safe
    end

    def destroy
      authorize! :destroy, @cupon
      if @cupon.usado?
        create_modal_form @cupon,
                          notice: "No se puede eliminar el cupón <strong>#{@cupon}</strong> porque está asociado a un pedido.".html_safe
      else
        @cupon.destroy!
        create_modal_form @cupon,
                          notice: "Cupón <strong>#{@cupon}</strong> eliminado correctamente.".html_safe
      end
    end

    def expirar_grupo
      authorize! :manage, Cupon
      Cupon.expirar_grupo!(params[:grupo])
      redirect_to cupones_path, notice: 'Grupo de cupones expirado correctamente.'
    end

    def eliminar_grupo
      authorize! :destroy, Cupon
      Cupon.eliminar_grupo!(params[:grupo])
      redirect_to cupones_path, notice: 'Grupo de cupones eliminado correctamente.'
    end

    def cancelar_grupo
      authorize! :manage, Cupon
      Cupon.cancelar_grupo!(params[:grupo])
      redirect_to cupones_path, notice: 'Cupones vigentes del grupo cancelados correctamente.'
    end

    def confirmar_eliminar
      authorize! :destroy, Cupon
      respond_to do |format|
        format.js { render 'confirmar_eliminar' }
      end
    end

    def eliminar_masivo
      authorize! :destroy, Cupon
      eliminados = Cupon.where(tienda: tienda_activa).eliminar_masivo(
        codigo: params[:codigo],
        grupo: params[:grupo]
      )
      redirect_to cupones_path, notice: "#{eliminados.size} cupón(es) eliminado(s) correctamente."
    end

    private

    def crear_cupones(attrs)
      cantidad = [params[:cantidad].to_i, 1].max
      cantidad = [cantidad, 500].min
      Cupon.crear_cantidad(cantidad, attrs)
    end

    def render_modal_form_with_errors
      respond_to do |format|
        format.js { render 'create' }
      end
    end

    def cupon_params
      params.require(:cupon).permit(:tienda_id,
                                    :tipo_descuento, :importe, :porcentaje, :limite_bonificacion,
                                    :fecha_vencimiento, :nombre)
    end
  end
end
