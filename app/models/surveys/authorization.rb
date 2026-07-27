module Surveys
  class Authorization < Ability::Subrules
    def add_rules
      if admin?
        can(:index, Surveys::Survey)
        can(:manage, Surveys::Survey) { |x| x.new_record? || x.tienda == user.tienda_activa }
        can(:manage, Surveys::Question) { |x| x.new_record? || x.survey.tienda == user.tienda_activa }
        can(:manage, Surveys::Answer) { |x| x.new_record? || x.question.survey.tienda == user.tienda_activa }
        can(:manage, Surveys::SurveyResponse) { |x| x.new_record? || x.survey.tienda == user.tienda_activa }
        can(:manage, Surveys::QuestionResponse) { |x| x.new_record? || x.question.survey.tienda == user.tienda_activa }
      else
        # Allow reading surveys from their tienda to respond to them
        can(:read, Surveys::Survey) do |survey|
          survey.tienda == user.tienda_activa
        end
        can(:create, Surveys::SurveyResponse)
        can :update, Surveys::SurveyResponse do |survey_response|
          survey_response.user == user && !survey_response.completed?
        end
        can :manage, Surveys::QuestionResponse do |question_response|
          question_response.survey_response.user == user && !question_response.survey_response.completed?
        end
      end
    end
  end
end
