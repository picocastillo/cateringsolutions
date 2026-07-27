module Surveys
  class Question < ApplicationRecord
    self.table_name = 'questiones'

    belongs_to :survey, class_name: 'Surveys::Survey'
    has_many :answers, dependent: :destroy, class_name: 'Surveys::Answer'
    has_many :question_responses, dependent: :destroy, class_name: 'Surveys::QuestionResponse'

    accepts_nested_attributes_for :answers, allow_destroy: true, reject_if: proc { |attrs| attrs['text'].blank? }

    validates :text, presence: true
    validates :question_type, presence: true, inclusion: { in: ['text', 'multiple_choice', 'scale'] }
    validates :required, inclusion: { in: [true, false] }
    validate :multiple_choice_has_answers, if: -> { question_type == 'multiple_choice' && !new_record? }

    def to_s
      text
    end

    def multiple_choice?
      question_type == 'multiple_choice'
    end

    def scale?
      question_type == 'scale'
    end

    def text?
      question_type == 'text'
    end

    private

    def multiple_choice_has_answers
      return unless answers.reject(&:marked_for_destruction?).none? { |a| a.text.present? }

      errors.add(:answers, 'debe tener al menos una opción')
    end
  end
end
