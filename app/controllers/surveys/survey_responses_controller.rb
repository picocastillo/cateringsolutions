module Surveys
  class SurveyResponsesController < ApplicationController
    before_action :set_survey
    before_action :set_survey_response, only: [:show, :destroy, :complete]

    def index
      # Always call authorize! first to satisfy check_authorization

      authorize! :index, Surveys::SurveyResponse

      # Base query with includes
      @survey_responses = @survey.survey_responses.includes(:question_responses, :user).order(created_at: :desc)

      # Apply text filter if present
      if params[:incluye_texto].present?
        @incluye_texto = params[:incluye_texto]
        # Filter responses that have text answers containing the search term
        @survey_responses = @survey_responses.joins(:question_responses)
                                             .joins('INNER JOIN questiones ON questiones.id = questiones_responses.question_id')
                                             .where('questiones.question_type = ? AND questiones_responses.response_text LIKE ?',
                                                    'text', "%#{@incluye_texto}%")
                                             .distinct
      end

      # Aggregate data for multiple-choice questions to render charts on index
      @mc_chart_data = {}
      @scale_chart_data = {}
      @survey.questions.includes(:answers).find_each do |q|
        next unless q.multiple_choice?

        answers = q.answers
        answers_by_id = answers.index_by(&:id)
        option_texts = answers.map(&:text)

        # Base scope: all responses for this survey/question (completed and incomplete)
        base = Surveys::QuestionResponse
               .joins(:survey_response)
               .where(question_id: q.id, survey_responses: { survey_id: @survey.id })

        # Fetch answer_id and response_text to aggregate per option
        rows = base.pluck(:answer_id, :response_text)

        totals = Hash.new(0)
        # Initialize known options to 0 to keep order stable
        option_texts.each { |t| totals[t] ||= 0 }

        rows.each do |aid, rtext|
          if aid.present? && answers_by_id[aid]
            totals[answers_by_id[aid].text] += 1
          elsif rtext.present?
            # Split multi-select texts by comma/semicolon and trim
            rtext.to_s.split(/[;,]/).map(&:strip).compact_blank.each do |choice|
              unless option_texts.include?(choice)
                # Count free-text/unknown options under their own label
              end
              totals[choice] += 1
            end
          end
        end

        labels = option_texts.presence || totals.keys
        # Include any extra labels discovered (not predefined) after known ones
        extras = totals.keys - labels
        labels += extras
        series = labels.map { |t| totals[t] || 0 }
        @mc_chart_data[q.id] = { labels: labels, series: series }
      end

      # Aggregate data for scale-type questions (values 1..5)
      @survey.questions.each do |q|
        next unless q.scale?

        # Base scope: all responses for this survey/question with a value
        base = Surveys::QuestionResponse
               .joins(:survey_response)
               .where(question_id: q.id, survey_responses: { survey_id: @survey.id })
               .where.not(response_text: [nil, ''])

        # Build counts in Ruby from the raw values to avoid DB COUNT
        value_list = base.pluck(:response_text)
        counts_by_value = value_list.each_with_object(Hash.new(0)) { |val, h| h[val.to_s] += 1 }
        labels = counts_by_value.keys.sort_by(&:to_i)
        series = labels.map { |v| counts_by_value[v] }
        @scale_chart_data[q.id] = { labels: labels, series: series }
      end
    rescue CanCan::AccessDenied
      # Handle authorization failure by redirecting appropriately
      if current_user.cliente?
        redirect_to new_pedido_path, notice: 'No tienes acceso a la lista de respuestas.'
      else
        redirect_to surveys_path, notice: 'No tienes permisos para ver las respuestas.'
      end
    end

    def show
      authorize! :read, @survey_response
      # Build aggregate data for multiple choice questions to render charts
      @mc_chart_data = {}
      @survey.questions.includes(:answers).find_each do |q|
        next unless q.multiple_choice?

        answers = q.answers
        answers_by_id = answers.index_by(&:id)
        option_texts = answers.map(&:text)

        # Count responses grouped by response_text (for when answer_id wasn't stored)
        counts_by_text = Surveys::QuestionResponse
                         .joins(:survey_response)
                         .where(question_id: q.id, survey_responses: { survey_id: @survey.id })
                         .where.not(response_text: [nil, ''])
                         .group(:response_text)
                         .count

        # Count responses grouped by answer_id (for when answer associations exist)
        counts_by_answer = Surveys::QuestionResponse
                           .joins(:survey_response)
                           .where(question_id: q.id, survey_responses: { survey_id: @survey.id })
                           .where.not(answer_id: nil)
                           .group(:answer_id)
                           .count

        totals = Hash.new(0)
        counts_by_text.each { |text, c| totals[text] += c }
        counts_by_answer.each do |aid, c|
          at = answers_by_id[aid]&.text
          totals[at] += c if at.present?
        end

        labels = option_texts.presence || totals.keys
        series = labels.map { |t| totals[t] || 0 }
        @mc_chart_data[q.id] = { labels: labels, series: series }
      end
    rescue CanCan::AccessDenied
      if current_user.cliente?
        redirect_to new_pedido_path, notice: 'No tienes acceso a ver respuestas.'
      else
        redirect_to surveys_path, notice: 'No tienes permisos para ver las respuestas.'
      end
    end

    def new
      authorize! :create, SurveyResponse

      # Check if user already has a response for this survey
      existing_response = @survey.survey_responses.find_by(user: current_user)
      if existing_response.present?
        if current_user.cliente?
          redirect_to new_pedido_path, alert: 'Ya has respondido esta encuesta'
        else
          redirect_to survey_path(@survey), alert: 'Ya has respondido esta encuesta'
        end
        return
      end

      @survey_response = @survey.survey_responses.build
      @survey_response.tienda_id = tienda_activa.id
      @survey.questions.each do |question|
        question_response = @survey_response.question_responses.build
        question_response.question = question
        question_response.question_id = question.id
      end
    end

    def create
      authorize! :create, SurveyResponse

      # Check if user already has a response for this survey
      existing_response = @survey.survey_responses.find_by(user: current_user)
      if existing_response.present?
        if current_user.cliente?
          redirect_to new_pedido_path, alert: 'Ya has respondido esta encuesta'
        else
          redirect_to survey_path(@survey), alert: 'Ya has respondido esta encuesta'
        end
        return
      end

      # Handle both simple response format and nested attributes format
      @survey_response = @survey.survey_responses.build
      @survey_response.user = current_user
      @survey_response.tienda_id = tienda_activa.id

      # Always handle the response format from the form
      # Create question responses for all questions in the survey
      @survey.questions.each do |question|
        question_response = @survey_response.question_responses.build
        question_response.question = question
        question_response.question_id = question.id

        # Get the submitted value from params, or empty string if not submitted
        submitted_value = params.dig(:response, question.id.to_s) || ''

        # Handle different response types
        question_response.response_text = if submitted_value.is_a?(Array)
                                            # For checkbox responses
                                            submitted_value.join(', ')
                                          else
                                            # For all response types, store in response_text
                                            submitted_value.to_s
                                          end

        Rails.logger.debug do
          "SURVEY RESPONSE: Created question_response for question #{question.id} " \
            "(required: #{question.required?}) with response_text: '#{question_response.response_text}'"
        end
      end

      if @survey_response.save
        Rails.logger.debug 'SURVEY RESPONSE: Save successful'
        if current_user.cliente?
          redirect_to new_pedido_path, notice: '¡Gracias por completar la encuesta!'
        else
          redirect_to survey_path(@survey), notice: 'Respuesta enviada exitosamente.'
        end
      else
        Rails.logger.debug { "SURVEY RESPONSE: Save failed with errors: #{@survey_response.errors.full_messages}" }
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      authorize! :destroy, @survey_response
      @survey_response.destroy
      redirect_to survey_survey_responses_path(@survey), notice: 'Respuesta eliminada exitosamente.'
    end

    def complete
      authorize! :update, @survey_response
      @survey_response.update!(completed_at: Time.current)
      redirect_to survey_path(@survey), notice: 'Respuesta marcada como completada.'
    end

    private

    def set_survey
      @survey = Survey.for_tienda(tienda_activa.id).find(params[:survey_id])
    end

    def set_survey_response
      @survey_response = @survey.survey_responses.find(params[:id])
    end

    def survey_response_params
      params.require(:survey_response).permit(
        question_responses_attributes: [:id, :question_id, :response_text, :response_value]
      )
    end
  end
end
