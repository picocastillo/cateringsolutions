module Surveys
  class SurveysController < ApplicationController
    before_action :set_survey, only: [:show, :edit, :update, :destroy, :respond]

    def index
      # Redirect client users to pedidos if they try to access survey management
      if current_user.cliente?
        redirect_to new_pedido_path, notice: 'No tienes acceso a la lista de encuestas.'
        return
      end
      authorize! :index, Survey

      # Optimize query to avoid N+1 queries
      @surveys = Survey.for_tienda(current_user.tienda_activa.id)
                       .includes(:questions, :survey_responses)
                       .left_joins(:questions, :survey_responses)
                       .select('surveys.*, COUNT(DISTINCT questiones.id) as questions_count,
                               COUNT(DISTINCT CASE WHEN survey_responses.completed_at IS NOT NULL THEN survey_responses.id END) as completed_responses_count')
                       .group('surveys.id')
                       .order(:title)
                       .paginate(page: params[:page], per_page: 20)
    end

    def show
      authorize! :read, @survey
      @total_responses = @survey.total_responses
      @user_response = current_user.present? ? @survey.survey_responses.find_by(user: current_user) : nil
    end

    def new
      authorize! :create, Survey
      @survey = Survey.new(tienda_id: current_user.tienda_activa.id)
      # Build a default question for the form
      @survey.questions.build
    end

    def edit
      authorize! :update, @survey
    end

    def create
      authorize! :create, Survey
      @survey = Survey.new(survey_params)
      @survey.tienda_id = current_user.tienda_activa.id

      if @survey.save
        redirect_to survey_path(@survey), notice: 'Encuesta creada exitosamente.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      authorize! :update, @survey
      if @survey.update(survey_params)
        redirect_to survey_path(@survey), notice: 'Encuesta actualizada exitosamente.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize! :destroy, @survey
      @survey.destroy
      redirect_to surveys_path, notice: 'Encuesta eliminada exitosamente.'
    end

    def respond
      # Public action for users to respond to surveys
      unless @survey.active?
        redirect_to surveys_path, alert: 'Esta encuesta no está disponible.'
        return
      end

      if @survey.fecha_desde && @survey.fecha_desde > Date.current
        redirect_to surveys_path, alert: 'Esta encuesta aún no está disponible.'
        return
      end

      if @survey.fecha_hasta && @survey.fecha_hasta < Date.current
        redirect_to surveys_path, alert: 'Esta encuesta ha expirado.'
        return
      end

      @survey_response = @survey.survey_responses.build
    end

    private

    def set_survey
      @survey = Survey.for_tienda(current_user.tienda_activa.id).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to surveys_path, alert: 'No se pudo encontrar la encuesta solicitada.'
    end

    def survey_params
      params.require(:survey).permit(:title, :description, :active, :fecha_desde, :fecha_hasta,
                                     questions_attributes: [:id, :text, :question_type, :required, :_destroy,
                                                            { answers_attributes: [:id, :text, :value, :_destroy] }])
    end
  end
end
