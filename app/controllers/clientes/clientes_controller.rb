module Clientes
  class ClientesController < ApplicationController
    load_and_authorize_resource except: [:index, :new, :lookup_by_cuit, :vincular_tienda, :create]
    before_action :authorize_create_or_change!, only: [:lookup_by_cuit, :vincular_tienda]

    def index
      respond_to do |format|
        format.any :html, :js do
          authorize! :index, Cliente
          @query = Clientes::ClientesQuery.new(query_params.merge(user: current_user))
          @clientes = @query.page(params[:page]).per_page(20)
        end
        format.json do
          if params[:for_autocomplete] == 'true'
            authorize! :index_js, Cliente
            render json: Clientes::ClientesParaAcQuery.new(request.parameters.merge(user: current_user)).limit(10)
                         .to_json(only: :id, methods: [:nombre, :to_s])
          else
            authorize! :index, Cliente
            q = if current_user.cliente?
                  Clientes::Cliente.disponibles_en(tienda_activa).where(id: current_user.cuenta.cliente.id)
                else
                  Clientes::Cliente.disponibles_en(tienda_activa)
                                   .where('clientes.nombre like ?', "%#{request.parameters[:q]}%")
                end
            q = q.status(:active) if request.parameters[:active] == 'true'
            render json: q.limit(10)
                         .to_json(only: :id, methods: [:nombre, :to_s])
          end
        end
      end
    end

    def new
      @cliente = Cliente.new(tiendas: [tienda_activa])
      authorize! :new, @cliente
    end

    def create
      @cliente = Cliente.new(cliente_params)
      # Ensure the creating admin's tienda is always attached.
      # This makes `disponible_en?(tienda_activa)` return true for the new
      # (unsaved) record so the authorization block passes, and guarantees the
      # new cliente is accessible in the admin's tienda after creation.
      @cliente.tiendas = (@cliente.tiendas.to_a | [tienda_activa])
      authorize! :create, @cliente
      if @cliente.save
        redirect_to @cliente, notice: "Cliente #{@cliente} creado correctamente."
      else
        render :new
      end
    end

    def update
      @cliente.assign_attributes cliente_params
      if @cliente.save
        redirect_to @cliente, notice: "Cliente #{@cliente} actualizado correctamente."
      else
        render :edit
      end
    end

    def stats
      respond_to do |format|
        format.js
      end
    end

    def financieros
      respond_to do |format|
        format.js
      end
    end

    def analytics
      respond_to do |format|
        format.js
      end
    end

    # AJAX endpoint for the new-cliente form: given a CUIT, look up an
    # existing cliente system-wide. Returns JSON describing whether it exists,
    # whether it is already linked to the current tienda, and (if not) the
    # tiendas where it lives so the user can confirm the link-and-edit action.
    def lookup_by_cuit
      digits = params[:cuit].to_s.gsub(/\D/, '')
      if digits.length != 11
        render json: { exists: false }
        return
      end

      cliente = Clientes::Cliente.active.where(cuit: digits).first
      if cliente.nil?
        # Not in our DB — try ARCA's padrón so the form can be prefilled.
        arca = Arca::PadronClient.fetch(digits)
        render json: { exists: false, arca: arca }
        return
      end

      render json: {
        exists: true,
        id: cliente.id,
        nombre: cliente.nombre,
        ya_vinculado: cliente.disponible_en?(tienda_activa),
        tiendas: cliente.tiendas.pluck(:nombre),
        edit_url: edit_cliente_path(cliente),
        vincular_url: vincular_tienda_cliente_path(cliente)
      }
    end

    # POST endpoint that links the current tienda_activa onto an existing
    # cliente (without creating a new row) and redirects to its edit page so
    # the admin can review/adjust.
    def vincular_tienda
      cliente = Clientes::Cliente.find(params[:id])
      cliente.tiendas << tienda_activa unless cliente.disponible_en?(tienda_activa)
      redirect_to edit_cliente_path(cliente),
                  notice: "Cliente #{cliente} vinculado a #{tienda_activa}. Revisá los datos y guardá si querés ajustarlos."
    end

    def cliente_params
      params.require(:cliente).permit(:corte, :nombre, :email, :dni, :domicilio, :telefono, :active, :cuit,
                                      :dia_inicio_ciclo_facturacion, :vencimiento_a,
                                      :permitir_envios_a_domicilio, :usuario_puede_elegir_cuenta,
                                      :cuenta_corriente, :listas_de_precio_privada,
                                      :mostrar_cuentas_corrientes, :horarios_de_entrega,
                                      :codigo_externo_en_etiquetas,
                                      :limite_compra_pesos, :limite_compra_dolares,
                                      categoria_ids: [], tienda_ids: [],
                                      cuentas_attributes: [:id, :nro, :nombre, :active,
                                                           :cuenta_corriente_parcial, :horario_corte_pedidos, :_destroy])
    end

    private

    def query_params
      clean_empty_string_in_arrays (request.parameters[:q].is_a?(String) ? nil : request.parameters[:q]).to_h.merge user: current_user
    end

    def authorize_create_or_change!
      # Mirror the `new` action: build with the current tienda so the
      # `disponible_en?(tienda_activa)` check in the authorization rules passes.
      authorize! :new, Clientes::Cliente.new(tiendas: [tienda_activa])
    end
  end
end
