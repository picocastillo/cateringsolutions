require 'rails_helper'

RSpec.describe Surveys::Answer, type: :model do
  let(:tienda) { create(:tienda) }
  let(:survey) { create(:survey, tienda: tienda) }
  let(:question) { create(:question, :multiple_choice, survey: survey) }

  describe 'validations' do
    it 'requires text' do
      answer = build(:answer, text: nil, question: question)
      expect(answer).not_to be_valid
      expect(answer.errors[:text]).to include('no puede estar en blanco')
    end

    it 'sets default value when value is blank' do
      answer = build(:answer, value: nil, question: question)
      answer.valid? # trigger validations and callbacks
      expect(answer.value).to be_present
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:question).class_name('Surveys::Question') }
  end
end
