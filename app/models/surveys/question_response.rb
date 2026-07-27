module Surveys
  class QuestionResponse < ApplicationRecord
    self.table_name = 'questiones_responses'

    belongs_to :survey_response, class_name: 'Surveys::SurveyResponse'
    belongs_to :question, class_name: 'Surveys::Question'
    belongs_to :answer, class_name: 'Surveys::Answer', optional: true

    # Validation for required questions is handled at the SurveyResponse level

    def response
      response_text
    end

    def answered?
      response_text.present?
    end

    def to_s
      answer&.text || response_text || 'Sin respuesta'
    end
  end
end
