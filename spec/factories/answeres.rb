FactoryBot.define do
  factory :answer, class: 'Surveys::Answer' do
    text { Faker::Lorem.words(number: 2).join(' ') }
    value { Faker::Lorem.word }

    association :question, factory: :question
  end
end
