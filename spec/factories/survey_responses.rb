FactoryBot.define do
  factory :survey_response, class: 'Surveys::SurveyResponse' do
    association :survey, factory: :survey
    association :user, factory: :usuario
    association :tienda, factory: :tienda
    completed_at { nil }

    trait :completed do
      completed_at { Time.current }
    end
  end
end
