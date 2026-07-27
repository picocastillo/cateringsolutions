FactoryBot.define do
  factory :survey, class: 'Surveys::Survey' do
    title { Faker::Lorem.sentence(word_count: 3) }
    description { Faker::Lorem.paragraph }
    active { true }
    fecha_desde { nil }
    fecha_hasta { nil }

    association :tienda, factory: :tienda

    # Include one question by default since validation requires it
    after(:build) do |survey|
      survey.questions.build(text: 'Default question', question_type: 'text', required: false)
    end

    trait :with_date_range do
      fecha_desde { 1.week.ago.to_date }
      fecha_hasta { 1.week.from_now.to_date }
    end

    trait :inactive do
      active { false }
    end

    trait :expired do
      fecha_desde { 2.weeks.ago.to_date }
      fecha_hasta { 1.week.ago.to_date }
    end

    trait :future do
      fecha_desde { 1.week.from_now.to_date }
      fecha_hasta { 2.weeks.from_now.to_date }
    end

    trait :with_questions do
      after(:build) do |survey|
        # Clear the default question and build multiple questions
        survey.questions.clear
        3.times do |i|
          survey.questions.build(text: "Question #{i + 1}", question_type: 'text', required: false)
        end
      end
    end

    trait :without_questions do
      after(:build) do |survey|
        # Clear the default question for testing - note this will fail validation if saved
        survey.questions.clear
      end
    end

    # For tests that need specific questions without default
    trait :empty do
      to_create { |instance| instance.save!(validate: false) }
      after(:build) do |survey|
        survey.questions.clear
      end
    end
  end
end
