FactoryBot.define do
  factory :question, class: 'Surveys::Question' do
    text { Faker::Lorem.question }
    question_type { 'text' }
    required { false }

    # Don't create a survey automatically to avoid circular dependency
    # Use build(:question, survey: your_survey) instead

    trait :required do
      required { true }
    end

    trait :multiple_choice do
      question_type { 'multiple_choice' }

      after(:create) do |question|
        create_list(:answer, 3, question: question)
      end
    end

    trait :scale do
      question_type { 'scale' }
    end
  end
end
