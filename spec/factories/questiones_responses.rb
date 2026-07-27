FactoryBot.define do
  factory :question_response, class: 'Surveys::QuestionResponse' do
    association :survey_response, factory: :survey_response
    association :question, factory: :question
    response_text { Faker::Lorem.paragraph }

    trait :with_text_response do
      response_text { Faker::Lorem.paragraph }
    end

    trait :with_answer do
      response_text { nil }
      association :answer, factory: :answer
    end
  end
end
