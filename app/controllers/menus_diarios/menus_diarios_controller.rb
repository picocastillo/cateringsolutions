module MenusDiarios
  class MenusDiariosController < ApplicationController
    load_resource except: :index
    include FormattingHelper
    include ActionView::Helpers::NumberHelper
    include MenusDiarios::TiposHelper

    before_action :disable_turbolinks_cache

    def index
      authorize! :new, MenuDiario
      respond_to do |format|
        format.html do
          @menu_diario = MenuDiario.new
          @menus_diarios = MenuDiario.where(tienda_id: tienda_activa.id)
        end
        format.json do
          @menus_diarios = MenuDiario.where(tienda_id: tienda_activa.id).includes(productos: :categoria).limit(15_000)
          @menus_diarios = @menus_diarios.where('fecha >=?', params[:start]) if params[:start].present?
          @menus_diarios = @menus_diarios.where('fecha <=?', params[:end]) if params[:end].present?
          @menus_diarios = @menus_diarios.joins(:productos).where(productos: { id: params[:producto_ids].split(',') }) if params[:producto_ids].present?
          render json: @menus_diarios.map { |t|
            visuals = menu_diario_tipo_visuals(t)
            productos_diarios = t.tipo_id == MenusDiarios::Tipo[:productos_diarios].id
            { id: t.id,
              title: create_title(t),
              start: t.fecha,
              end: t.fecha,
              'className' => "evento-cal-#{t.id}#{' evento-cal-productos-diarios' if productos_diarios}",
              'backgroundColor' => productos_diarios ? visuals[:color] : t.productos.first.try(&:color_safe),
              'borderColor' => productos_diarios ? '#7c3aed' : nil,
              :tooltip => 'Editar' }
          }
        end
      end
    end

    def create_title(menu)
      visuals = menu_diario_tipo_visuals(menu)
      productos_label = menu.productos.map { |x| x.to_s.html_safe }.join("\n")
      title = []
      title << "#{visuals[:emoji]} "
      title << (productos_label.presence || (menu.tipo_id == MenusDiarios::Tipo[:productos_diarios].id ? 'Opciones del día' : ''))
      title << "\n\n#{menu.descripcion}" if menu.descripcion.present?
      title << ":\nObservaciones:\n#{menu.observaciones}" if menu.observaciones.present?
      title.join(' ').html_safe
    end

    def new
      authorize! :new, MenuDiario
      @evento_cal_id = 0
      @menu_diario = if params[:fecha].present?
                       MenuDiario.new(tienda: tienda_activa, fecha: Date.parse(params[:fecha]))
                     else
                       MenuDiario.new tienda: tienda_activa
                     end
      new_modal_form
    end

    def productos_disponibles
      authorize! :new, MenuDiario
      fecha = begin
        Date.parse(params[:fecha])
      rescue StandardError
        nil
      end
      return render(json: { pd: [], md: [] }) unless fecha

      exclude_id = params[:exclude_id].presence&.to_i
      ya_usados_scope = MenuDiario.productos_diarios
                                  .where(tienda_id: tienda_activa.id, fecha: fecha, discontinued_at: nil)
      ya_usados_scope = ya_usados_scope.where.not(id: exclude_id) if exclude_id
      ya_usados_pd_ids = ya_usados_scope.joins(:productos).pluck('productos.id').to_set

      productos_todos = Productos::Producto.where(tienda_id: tienda_activa).joins(:categoria).active.includes(:categoria)
      productos_md = productos_todos.select { |p| p.categoria&.menu_diario }
      productos_pd = productos_todos.reject { |p| p.categoria&.menu_diario }
                                    .reject { |p| ya_usados_pd_ids.include?(p.id) }

      to_payload = lambda { |p|
        { id: p.id, codigo: p.codigo.to_s, nombre: p.nombre.to_s,
          label: p.to_s, categoria: p.categoria&.to_s,
          color: p.try(:color_safe) || '#989898' }
      }
      render json: { md: productos_md.map(&to_payload), pd: productos_pd.map(&to_payload) }
    end

    def edit
      authorize! :edit, @menu_diario
      @evento_cal_id = 0
      new_modal_form
    end

    def create
      authorize! :create, @menu_diario
      @menu_diario.autor = current_user
      @menu_diario.save
      @evento_cal_id = @menu_diario.id
      create_modal_form @menu_diario, notice: "#{@menu_diario.to_s_growl} creado correctamente."
    end

    def update
      authorize! :update, @menu_diario
      @menu_diario.assign_attributes menu_diario_params
      @menu_diario.save
      @evento_cal_id = @menu_diario.id
      create_modal_form @menu_diario, notice: "#{@menu_diario.to_s_growl} actualizado correctamente."
    end

    def destroy
      authorize! :destroy, @menu_diario
      @evento_cal_id = 0
      @menu_diario.destroy!
      create_modal_form @menu_diario, notice: "#{@menu_diario.to_s_growl} eliminado correctamente."
    end

    def menu_diario_params
      params.require(:menu_diario).permit(:fecha, :tienda_id, :descripcion, :observaciones, :id, :_destroy,
                                          :tipo_id, producto_ids: [])
    end
  end
end
