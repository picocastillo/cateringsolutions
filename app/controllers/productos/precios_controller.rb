module Productos
  class PreciosController < ApplicationController
    load_resource except: :index

    def index
      authorize! :index, Precio
      respond_to do |format|
        format.json do
          r = {}
          if params[:fecha].present? && (params[:usuario_id].present? || params[:cuenta_id].present?)
            fecha = params[:fecha].to_date
            cuenta = Clientes::Cuenta.where(id: params[:cuenta_id].to_i).first || Usuarios::Usuario.where(id: params[:usuario_id].to_i).first
            if cuenta
              r = Productos::PreciosParaAcQuery.new(request.parameters.merge(current_user: current_user,
                                                                             cuenta: cuenta, nombre: params[:q])).limit(10).map do |x|
                x.buscar_precio(cuenta.cliente, fecha)
              end.compact.map do |x|
                if x.producto.categoria.menu_diario
                  if (md = x.producto.menus_diarios.where(fecha: params[:fecha].to_date, tipo_id: ::MenusDiarios::Tipo[:menu_diario].id).first)
                    { id: x.producto.id, nombre: "#{x.producto} - #{md.descripcion.capitalize}", precio: Danconia::Money.new(x.importe), nombre_y_precio: x.nombre_codigos_y_precio(md), nombre_corto_y_precio: x.nombre_corto_y_precio(md) }
                  else
                    {}
                  end
                else
                  { id: x.producto.id, nombre: x.producto.to_s, precio: Danconia::Money.new(x.importe), nombre_y_precio: x.nombre_codigos_y_precio, nombre_corto_y_precio: x.nombre_corto_y_precio }
                end
              end.compact_blank
            end
          end
          render json: r.to_json
        end
      end
    end
  end
end
