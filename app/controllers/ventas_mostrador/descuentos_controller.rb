module VentasMostrador
  class DescuentosController < ApplicationController
    before_action :set_descuento, only: [:edit, :update, :destroy, :toggle_activo]

    def index
      authorize! :index, DescuentoVentaMostrador
      @descuentos = DescuentoVentaMostrador.where(tienda: tienda_activa)
                                           .includes(:clientes)
                                           .order(activo: :desc, nombre: :asc)
    end

    def new
      authorize! :new, DescuentoVentaMostrador
      @descuento = DescuentoVentaMostrador.new(tienda: tienda_activa, tipo_descuento: 'porcentaje', activo: true)
      new_modal_form
    end

    def edit
      authorize! :edit, @descuento
      new_modal_form
    end

    def create
      authorize! :create, DescuentoVentaMostrador
      @descuento = DescuentoVentaMostrador.new(descuento_params.merge(tienda_id: tienda_activa.id))
      @descuento.save
      create_modal_form @descuento,
                        notice: "Descuento <strong>#{@descuento.nombre}</strong> creado correctamente.".html_safe
    end

    def update
      authorize! :update, @descuento
      @descuento.assign_attributes descuento_params
      @descuento.save
      create_modal_form @descuento,
                        notice: "Descuento <strong>#{@descuento.nombre}</strong> actualizado correctamente.".html_safe
    end

    def destroy
      authorize! :destroy, @descuento
      @descuento.destroy!
      create_modal_form @descuento,
                        notice: "Descuento <strong>#{@descuento.nombre}</strong> eliminado correctamente.".html_safe
    end

    def toggle_activo
      authorize! :update, @descuento
      @descuento.update!(activo: !@descuento.activo)
      estado = @descuento.activo? ? 'activado' : 'desactivado'
      redirect_to ventas_mostrador_descuentos_path,
                  notice: "Descuento \"#{@descuento.nombre}\" #{estado} correctamente."
    end

    private

    def set_descuento
      @descuento = DescuentoVentaMostrador.find(params[:id])
    end

    def descuento_params
      params.require(:descuento_venta_mostrador).permit(
        :nombre, :tipo_descuento, :importe, :porcentaje, :limite_bonificacion,
        :medio_pago_tipo, :importe_minimo, :activo, cliente_ids: []
      )
    end
  end
end
