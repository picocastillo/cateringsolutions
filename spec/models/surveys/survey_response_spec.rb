require 'rails_helper'

RSpec.describe Surveys::SurveyResponse, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:survey).class_name('Surveys::Survey') }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:question_responses).class_name('Surveys::QuestionResponse').dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:survey_response, survey: survey, user: user, tienda: tienda) }

    let(:survey) { create(:survey) } # Keep default here since this test doesn't add extra questions
    let(:user) { create(:user) }
    let(:tienda) { create(:tienda) }

    it { is_expected.to be_valid }

    context 'when survey already has a response from the user' do
      before do
        create(:survey_response, survey: survey, user: user, tienda: tienda)
      end

      it 'does not allow duplicate responses from the same user' do
        duplicate_response = build(:survey_response, survey: survey, user: user, tienda: tienda)
        expect(duplicate_response).not_to be_valid
        expect(duplicate_response.errors[:user_id]).to include('ya ha respondido esta encuesta')
      end
    end
  end

  describe '#completed?' do
    let(:survey) { create(:survey, :empty) }
    let(:user) { create(:user) }
    let!(:question1) { create(:question, survey: survey, required: true) }
    let!(:question2) { create(:question, survey: survey, required: false) }
    let(:response) { create(:survey_response, survey: survey, user: user) }

    context 'when all required questions are answered' do
      before do
        create(:question_response, survey_response: response, question: question1, response_text: 'Answer 1')
        response.save # Trigger the after_save callback
        response.reload
      end

      it 'auto-completes the response' do
        expect(response.completed?).to be true
        expect(response.completed_at).to be_present
      end
    end

    context 'when not all required questions are answered' do
      it 'returns false' do
        expect(response.completed?).to be false
      end
    end
  end

  describe '#progress_percentage' do
    let(:survey) { create(:survey, :empty) }
    let(:user) { create(:user) }
    let!(:question1) { create(:question, survey: survey) }
    let!(:question2) { create(:question, survey: survey) }
    let!(:question3) { create(:question, survey: survey) }
    let(:response) { create(:survey_response, survey: survey, user: user) }

    context 'when no questions are answered' do
      it 'returns 0' do
        expect(response.progress_percentage).to eq(0)
      end
    end

    context 'when some questions are answered' do
      before do
        create(:question_response, survey_response: response, question: question1, response_text: 'Answer 1')
      end

      it 'returns the correct percentage' do
        expect(response.progress_percentage).to eq(33)
      end
    end

    context 'when all questions are answered' do
      before do
        create(:question_response, survey_response: response, question: question1, response_text: 'Answer 1')
        create(:question_response, survey_response: response, question: question2, response_text: 'Answer 2')
        create(:question_response, survey_response: response, question: question3, response_text: 'Answer 3')
        # Force reload to clear any cached associations
        response.reload
      end

      it 'returns 100' do
        expect(response.progress_percentage).to eq(100)
      end
    end
  end

  describe '#answered_questions_count' do
    let(:survey) { create(:survey, :empty) }
    let(:user) { create(:user) }
    let!(:question1) { create(:question, survey: survey) }
    let!(:question2) { create(:question, survey: survey) }
    let(:response) { create(:survey_response, survey: survey, user: user) }

    context 'when no questions are answered' do
      it 'returns 0' do
        expect(response.answered_questions_count).to eq(0)
      end
    end

    context 'when some questions are answered' do
      before do
        create(:question_response, survey_response: response, question: question1, response_text: 'Answer 1')
      end

      it 'returns the correct count' do
        expect(response.answered_questions_count).to eq(1)
      end
    end
  end

  describe '#total_questions_count' do
    let(:survey) { create(:survey, :empty) }
    let(:user) { create(:user) }
    let!(:question1) { create(:question, survey: survey) }
    let!(:question2) { create(:question, survey: survey) }
    let(:response) { create(:survey_response, survey: survey, user: user) }

    it 'returns the total number of questions in the survey' do
      expect(response.total_questions_count).to eq(2)
    end
  end
end
