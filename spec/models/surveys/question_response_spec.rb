require 'rails_helper'

RSpec.describe Surveys::QuestionResponse, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:survey_response).class_name('Surveys::SurveyResponse') }
    it { is_expected.to belong_to(:question).class_name('Surveys::Question') }
  end

  describe 'validations' do
    subject { build(:question_response, survey_response: survey_response, question: question) }

    let(:survey) { create(:survey) }
    let(:user) { create(:user) }
    let(:survey_response) { create(:survey_response, survey: survey, user: user) }
    let(:question) { create(:question, survey: survey) }

    it { is_expected.to be_valid }

    context 'when question is required' do
      let(:question) { create(:question, survey: survey, required: true) }

      it 'is valid even without response_text (validation is at SurveyResponse level)' do
        response = build(:question_response,
                         survey_response: survey_response,
                         question: question,
                         response_text: nil)
        expect(response).to be_valid
      end

      it 'is valid with response_text' do
        response = build(:question_response,
                         survey_response: survey_response,
                         question: question,
                         response_text: 'Valid response')
        expect(response).to be_valid
      end
    end

    context 'when question is not required' do
      let(:question) { create(:question, survey: survey, required: false) }

      it 'is valid without response' do
        response = build(:question_response,
                         survey_response: survey_response,
                         question: question,
                         response_text: nil)
        expect(response).to be_valid
      end
    end
  end

  describe '#response' do
    let(:survey) { create(:survey) }
    let(:user) { create(:user) }
    let(:survey_response) { create(:survey_response, survey: survey, user: user) }
    let(:question) { create(:question, survey: survey) }

    context 'when response_text is present' do
      let(:question_response) do
        create(:question_response,
               survey_response: survey_response,
               question: question,
               response_text: 'Text response')
      end

      it 'returns response_text' do
        expect(question_response.response).to eq('Text response')
      end
    end

    context 'when response_text is not present' do
      let(:question_response) do
        create(:question_response,
               survey_response: survey_response,
               question: question,
               response_text: nil)
      end

      it 'returns nil' do
        expect(question_response.response).to be_nil
      end
    end
  end

  describe '#answered?' do
    let(:survey) { create(:survey) }
    let(:user) { create(:user) }
    let(:survey_response) { create(:survey_response, survey: survey, user: user) }
    let(:question) { create(:question, survey: survey) }

    context 'when response_text is present' do
      let(:question_response) do
        create(:question_response,
               survey_response: survey_response,
               question: question,
               response_text: 'Answer')
      end

      it 'returns true' do
        expect(question_response.answered?).to be true
      end
    end

    context 'when response_text is blank' do
      let(:question_response) do
        create(:question_response,
               survey_response: survey_response,
               question: question,
               response_text: '')
      end

      it 'returns false' do
        expect(question_response.answered?).to be false
      end
    end
  end
end
