require 'rails_helper'

RSpec.describe Surveys::QuestionResponse, type: :model do
  let(:tienda) { create(:tienda) }
  let(:survey) { create(:survey, tienda: tienda) }
  let(:question) { create(:question, survey: survey) }
  let(:survey_response) { create(:survey_response, survey: survey) }

  describe 'associations' do
    it { is_expected.to belong_to(:question).class_name('Surveys::Question') }
    it { is_expected.to belong_to(:survey_response).class_name('Surveys::SurveyResponse') }
  end

  describe 'validations' do
    context 'when question is required' do
      let(:required_question) { create(:question, :required, survey: survey) }

      it 'is valid even without response_text (validation is handled at SurveyResponse level)' do
        question_response = build(:question_response,
                                  question: required_question,
                                  survey_response: survey_response,
                                  response_text: nil)
        expect(question_response).to be_valid
      end
    end
  end
end
