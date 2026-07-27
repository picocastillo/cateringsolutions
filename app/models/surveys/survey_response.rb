module Surveys
  class SurveyResponse < ApplicationRecord
    belongs_to :survey, class_name: 'Surveys::Survey'
    belongs_to :user, class_name: 'Usuarios::Usuario'
    belongs_to :tienda, class_name: 'Tiendas::Tienda'
    has_many :question_responses, dependent: :destroy, class_name: 'Surveys::QuestionResponse'

    validates :user_id, uniqueness: { scope: :survey_id, message: 'ya ha respondido esta encuesta' }

    # Custom validation for required questions
    validate :all_required_questions_must_be_answered

    # Automatically mark as completed when all required questions are answered
    after_save :auto_complete_if_ready

    scope :completed, -> { where.not(completed_at: nil) }
    scope :incomplete, -> { where(completed_at: nil) }
    scope :for_tienda, ->(tienda_id) { where(tienda_id: tienda_id) }

    def completed?
      # Always check completed_at first
      completed_at.present?
    end

    def all_required_questions_answered?
      # Check if all required questions have been answered
      required_questions = survey.questions.where(required: true)
      return true if required_questions.none?

      answered_required_questions = question_responses.joins(:question)
                                                      .where(questiones: { required: true })
                                                      .where.not(response_text: [nil, ''])

      answered_required_questions.count == required_questions.count
    end

    def mark_as_completed!
      update!(completed_at: Time.current)
    end

    def progress_percentage
      return 0 if total_questions_count.zero?

      (answered_questions_count.to_f / total_questions_count * 100).round
    end

    def answered_questions_count
      question_responses.joins(:question)
                        .where.not(questiones_responses: { response_text: [nil, ''] })
                        .count
    end

    def total_questions_count
      survey.questions.count
    end

    def to_s
      "#{survey.title} - #{begin
        user.nombre
      rescue StandardError
        user.to_s
      end}"
    end

    private

    def all_required_questions_must_be_answered
      # Only validate if we have question_responses (i.e., this is a form submission)
      return if question_responses.empty?

      required_questions = survey.questions.where(required: true)
      return if required_questions.none?

      required_questions.each do |question|
        question_response = question_responses.find { |qr| qr.question_id == question.id }

        next unless question_response.nil? || question_response.response_text.blank?

        errors.add(:base, 'Se encontraron errores') unless errors[:base].include?('Se encontraron errores')
        errors.add(:base, "La pregunta '#{question.text}' es requerida")
      end
    end

    def auto_complete_if_ready
      # Only auto-complete if not already completed and all required questions are answered
      return unless completed_at.nil? && all_required_questions_answered?

      update_column(:completed_at, Time.current)
    end
  end
end
