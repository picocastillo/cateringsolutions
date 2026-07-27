module Usuarios
  class UsuariosController < ApplicationController
    load_resource
    before_action :build_user, only: [:seleccion_cliente, :seleccion_rol]

    def index
      respond_to do |format|
        format.any :html, :js do
          authorize! :index, Usuario
          @query = UsuariosQuery.new query_params
          @usuarios = @query.page(params[:page]).per_page(20)
          @roles = Rol.order(:modulo, :descripcion).group_by(&:modulo).each.map do |modulo, roles|
            OpenStruct.new nombre: modulo, roles: roles
          end
        end
        format.json do
          authorize! :index_js, Usuario
          render json: Usuarios::UsuariosParaAcQuery.new(request.parameters.merge(user: current_user)).limit(10)
                       .to_json(only: :id, methods: [:nombre, :to_s, :nombre_y_cliente,
                                                     :nombre_legajo_dni_cliente])
        end
        format.xls do
          authorize! :xls_index, Usuario
          export_in_background UsuariosExporter
        end
      end
    end

    def show
      authorize! :show, @usuario
      respond_to do |format|
        format.html
        format.pdf { render_pdf silent_print: true }
      end
    end

    def stats
      authorize! :show, @usuario
      base = Productos::ProductoSolicitado
             .joins(:pedido, :producto)
             .where(pedidos: { usuario_id: @usuario.id, tienda_id: current_user.tienda_activa })
             .where.not(pedidos: { estado_id: [1, 5] })

      @productos_favoritos = base
                             .group('productos.id', 'productos.nombre')
                             .order(Arel.sql('SUM(productos_solicitados.cantidad) DESC'))
                             .limit(5)
                             .pluck(Arel.sql('productos.nombre, SUM(productos_solicitados.cantidad)'))

      @productos_favoritos_3m = base
                                .where(pedidos: { fecha: 3.months.ago.to_date.. })
                                .group('productos.id', 'productos.nombre')
                                .order(Arel.sql('SUM(productos_solicitados.cantidad) DESC'))
                                .limit(5)
                                .pluck(Arel.sql('productos.nombre, SUM(productos_solicitados.cantidad)'))

      respond_to do |format|
        format.js
      end
    end

    def new
      authorize! :new, Usuario
      @usuario = Usuario.new
      @usuario.roles = Rol.sugeridos
    end

    def edit
      authorize! :edit, @usuario
    end

    def import
      authorize! :manage, Usuarios::Usuario

      return unless tienda_activa.dominio == request.domain(2) || Rails.env.development?

      import_in_background Usuarios::UsuariosImporter, false
      redirect_to usuarios_path, notice: 'La importación de usuarios se está procesando en segundo plano.'
    end

    def seleccion_cliente
      @usuario.nombre = @usuario.cliente&.nombre
      @usuario.email = @usuario.cliente&.email
      render partial: 'fields'
    end

    def seleccion_rol
      render partial: 'usuarios/perfiles/fields_notificaciones'
    end

    def create
      authorize! :create, Usuario
      @usuario.tienda_cliente = tienda_activa if @usuario.cliente?
      if @usuario.save
        redirect_to @usuario, notice: "Usuario #{@usuario} creado correctamente."
      else
        render :new
      end
    end

    def update
      authorize! :update, @usuario
      if @usuario.update usuario_params
        @usuario.touch
        respond_to do |format|
          format.html { redirect_to @usuario, notice: "Usuario #{@usuario} actualizado correctamente." }
          format.js { render js: 'refreshPage()' }
        end
      else
        render :edit
      end
    end

    def reset_codigo
      @usuario.update! codigo: nil
      redirect_to @usuario
    end

    def cambiar_tienda_cliente
      authorize! :update, @usuario
      @usuario.update_column(:tienda_cliente_id, params[:tienda_cliente_id].presence&.to_i)
      respond_to do |format|
        format.js
      end
    end

    private

    def usuario_params
      params.require(:usuario).permit(:login, :nombre, :tipo_usuario_id, :local_id, :cuenta_id, :password_confirmation,
                                      :password, :email, :telefono, :administrador_de_empresa, :nro,
                                      :sucursal, :dni, :legajo, :active, :solicitar_cambio_contrasena,
                                      :cuit, :tipo_id, :tienda_cliente_id, rol_ids: [], documento_ids: [],
                                                                           suscripciones_attributes: [], tienda_ids: [])
    end

    def build_user
      @usuario = params[:id] ? Usuario.find(params[:id]) : Usuario.new
      @usuario.attributes = usuario_params
    end
  end
end
