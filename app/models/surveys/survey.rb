module Surveys
  class Survey < ApplicationRecord
    belongs_to :tienda, class_name: 'Tiendas::Tienda'
    has_many :questions, dependent: :destroy, class_name: 'Surveys::Question'
    has_many :survey_responses, dependent: :destroy, class_name: 'Surveys::SurveyResponse'

    accepts_nested_attributes_for :questions, allow_destroy: true, reject_if: proc { |attrs|
      attrs['text'].blank? || attrs['question_type'].blank? || (attrs['_destroy'] == '1')
    }

    validates :title, presence: true
    validates :active, inclusion: { in: [true, false] }
    validate :fecha_hasta_after_fecha_desde, if: -> { fecha_desde.present? && fecha_hasta.present? }
    validate :must_have_at_least_one_question

    scope :active, -> { where(active: true) }
    scope :for_tienda, ->(tienda_id) { where(tienda_id: tienda_id) }
    scope :current, -> { where('fecha_desde <= ? AND fecha_hasta >= ?', Date.current, Date.current) }

    def to_s
      title
    end

    def total_responses
      # Use precomputed count if available (from controller query), otherwise fallback to database query
      if respond_to?(:completed_responses_count) && completed_responses_count
        completed_responses_count
      else
        survey_responses.where.not(completed_at: nil).count
      end
    end

    def questions_count_optimized
      # Use precomputed count if available (from controller query), otherwise fallback to association count
      if respond_to?(:questions_count) && questions_count
        questions_count
      else
        questions.count
      end
    end

    def active_period?
      return true if fecha_desde.blank? && fecha_hasta.blank?

      today = Date.current
      (fecha_desde.blank? || fecha_desde <= today) &&
        (fecha_hasta.blank? || fecha_hasta >= today)
    end

    def date_range_text
      return 'Sin límite de fechas' if fecha_desde.blank? && fecha_hasta.blank?
      return "Desde #{fecha_desde.strftime('%d/%m/%Y')}" if fecha_hasta.blank?
      return "Hasta #{fecha_hasta.strftime('%d/%m/%Y')}" if fecha_desde.blank?

      "#{fecha_desde.strftime('%d/%m/%Y')} - #{fecha_hasta.strftime('%d/%m/%Y')}"
    end

    private

    def must_have_at_least_one_question
      return unless questions.reject(&:marked_for_destruction?).none? { |q| q.text.present? }

      errors.add(:questions, 'debe tener al menos una pregunta')
    end

    def fecha_hasta_after_fecha_desde
      errors.add(:fecha_hasta, 'debe ser posterior a la fecha de inicio') if fecha_hasta < fecha_desde
    end
  end
end
