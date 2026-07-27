module Surveys
  class Answer < ApplicationRecord
    self.table_name = 'answeres'

    belongs_to :question, class_name: 'Surveys::Question'
    has_many :question_responses, dependent: :destroy, class_name: 'Surveys::QuestionResponse'

    validates :text, presence: true
    # Set default value before validation if not provided
    before_validation :set_default_value

    def to_s
      text
    end

    private

    def set_default_value
      return if value.present?

      # Set value based on position in question's answers collection
      self.value = question&.answers&.count.to_i + 1
    end
  end
end
