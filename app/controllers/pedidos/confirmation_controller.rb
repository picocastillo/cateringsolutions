module Pedidos
  class ConfirmationController < ApplicationController
    def show
      @pedido = Pedidos::Pedido.where(confirmation_token: params[:id],
                                      id: params[:pedido_id]).first
      authorize! :show, @pedido
      if @pedido.confirmar_y_crear_pago current_user, params[:payment_id], params[:merchant_order_id]
        redirect_to pedido_path(@pedido),
                    notice: "El pago fue recibido correctamente. el Pedido #{@pedido} ha sido confirmado."
      else
        redirect_to pedido_path(@pedido)
      end
    end
  end
end
