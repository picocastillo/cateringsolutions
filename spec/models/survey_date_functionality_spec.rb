require 'rails_helper'

RSpec.describe 'Simple Survey Test', type: :model do
  it 'can create a survey' do
    tienda = create(:tienda)
    survey = create(:survey, tienda: tienda)

    expect(survey).to be_persisted
    expect(survey.title).to be_present
    expect(survey.tienda).to eq(tienda)
  end

  it 'validates date range' do
    tienda = create(:tienda)
    survey = build(:survey,
                   tienda: tienda,
                   fecha_desde: 2.weeks.from_now,
                   fecha_hasta: 1.week.from_now)

    expect(survey).not_to be_valid
    expect(survey.errors[:fecha_hasta]).to include('debe ser posterior a la fecha de inicio')
  end

  it 'handles date range text correctly' do
    tienda = create(:tienda)

    # Test without dates
    survey_no_dates = create(:survey, tienda: tienda, fecha_desde: nil, fecha_hasta: nil)
    expect(survey_no_dates.date_range_text).to eq('Sin límite de fechas')

    # Test with dates
    survey_with_dates = create(:survey,
                               tienda: tienda,
                               fecha_desde: Date.new(2025, 8, 1),
                               fecha_hasta: Date.new(2025, 8, 31))
    expect(survey_with_dates.date_range_text).to eq('01/08/2025 - 31/08/2025')
  end

  it 'checks active period correctly' do
    tienda = create(:tienda)

    # Always active (no date restrictions)
    always_active = create(:survey, tienda: tienda, fecha_desde: nil, fecha_hasta: nil)
    expect(always_active.active_period?).to be true

    # Currently active
    currently_active = create(:survey,
                              tienda: tienda,
                              fecha_desde: 1.week.ago,
                              fecha_hasta: 1.week.from_now)
    expect(currently_active.active_period?).to be true

    # Future survey (not yet active)
    future_survey = create(:survey,
                           tienda: tienda,
                           fecha_desde: 1.week.from_now,
                           fecha_hasta: 2.weeks.from_now)
    expect(future_survey.active_period?).to be false

    # Expired survey
    expired_survey = create(:survey,
                            tienda: tienda,
                            fecha_desde: 2.weeks.ago,
                            fecha_hasta: 1.week.ago)
    expect(expired_survey.active_period?).to be false
  end
end
