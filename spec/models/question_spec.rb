require 'rails_helper'

RSpec.describe Surveys::Question, type: :model do
  let(:tienda) { create(:tienda) }
  let(:survey) { create(:survey, tienda: tienda) }

  describe 'validations' do
    it 'requires text' do
      question = build(:question, text: nil, survey: survey)
      expect(question).not_to be_valid
      expect(question.errors[:text]).to include('no puede estar en blanco')
    end

    it 'requires a question_type' do
      question = build(:question, question_type: nil, survey: survey)
      expect(question).not_to be_valid
      expect(question.errors[:question_type]).to include('no puede estar en blanco')
    end

    it 'validates question_type inclusion' do
      question = build(:question, question_type: 'invalid_type', survey: survey)
      expect(question).not_to be_valid
      expect(question.errors[:question_type]).to include('no está incluido en la lista')
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:survey).class_name('Surveys::Survey') }
    it { is_expected.to have_many(:answers).dependent(:destroy).class_name('Surveys::Answer') }
    it { is_expected.to have_many(:question_responses).dependent(:destroy).class_name('Surveys::QuestionResponse') }
  end

  describe 'question types' do
    it 'accepts valid question types' do
      ['text', 'multiple_choice', 'scale'].each do |type|
        question = build(:question, question_type: type, survey: survey)
        expect(question).to be_valid
      end
    end
  end
end
