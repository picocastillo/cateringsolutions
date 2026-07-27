require 'rails_helper'

RSpec.describe Surveys::SurveyResponse, type: :model do
  let(:tienda) { create(:tienda) }
  let(:survey) { create(:survey, tienda: tienda) }

  describe 'associations' do
    it { is_expected.to belong_to(:survey).class_name('Surveys::Survey') }
    it { is_expected.to have_many(:question_responses).dependent(:destroy).class_name('Surveys::QuestionResponse') }
  end

  describe '#completed?' do
    it 'returns true when completed_at is set' do
      response = create(:survey_response, survey: survey, completed_at: Time.current)
      expect(response.completed?).to be true
    end

    it 'returns false when completed_at is nil' do
      # Create the response without triggering the auto-completion callback
      response = build(:survey_response, survey: survey, completed_at: nil)
      response.save(validate: false)
      response.update_column(:completed_at, nil) # Ensure it's nil
      expect(response.completed?).to be false
    end
  end
end
