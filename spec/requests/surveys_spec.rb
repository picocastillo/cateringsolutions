require 'rails_helper'

RSpec.describe 'Survey Management', type: :request do
  let(:tienda) { create(:tienda) }
  let(:admin_user) { create(:usuario, :admin, visualizando_tienda: tienda) }

  before do
    # Set up authentication for tests
    # User is already created with visualizando_tienda set to tienda
    login_as(admin_user)
  end

  describe 'POST /surveys' do
    context 'with valid parameters including date range' do
      let(:valid_attributes) do
        {
          title: 'Test Survey with Dates',
          description: 'A test survey with date range',
          active: true,
          fecha_desde: 1.week.from_now.to_date,
          fecha_hasta: 2.weeks.from_now.to_date,
          questions_attributes: {
            '0' => {
              text: 'What is your favorite color?',
              question_type: 'text',
              required: false
            }
          }
        }
      end

      it 'creates a new survey with date range' do
        expect do
          post surveys_path, params: { survey: valid_attributes }
        end.to change(Surveys::Survey, :count).by(1)

        survey = Surveys::Survey.last
        expect(survey.title).to eq('Test Survey with Dates')
        expect(survey.fecha_desde).to eq(1.week.from_now.to_date)
        expect(survey.fecha_hasta).to eq(2.weeks.from_now.to_date)
        expect(survey.tienda).to eq(tienda)
      end

      it 'redirects to the survey show page' do
        post surveys_path, params: { survey: valid_attributes }
        expect(response).to redirect_to(survey_path(Surveys::Survey.last))
      end
    end

    context 'with invalid date range' do
      let(:invalid_date_attributes) do
        {
          title: 'Test Survey',
          description: 'A test survey',
          active: true,
          fecha_desde: 2.weeks.from_now.to_date,
          fecha_hasta: 1.week.from_now.to_date, # End date before start date
          questions_attributes: {
            '0' => {
              text: 'Sample question',
              question_type: 'text',
              required: false
            }
          }
        }
      end

      it 'does not create a new survey' do
        expect do
          post surveys_path, params: { survey: invalid_date_attributes }
        end.not_to change(Surveys::Survey, :count)
      end

      it 'shows validation error' do
        post surveys_path, params: { survey: invalid_date_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without required title' do
      let(:invalid_attributes) do
        {
          title: '',
          description: 'A test survey',
          active: true,
          questions_attributes: {
            '0' => {
              text: 'Sample question',
              question_type: 'text',
              required: false
            }
          }
        }
      end

      it 'does not create a new survey' do
        expect do
          post surveys_path, params: { survey: invalid_attributes }
        end.not_to change(Surveys::Survey, :count)
      end
    end
  end

  describe 'GET /surveys/new' do
    it 'returns success' do
      get new_survey_path
      expect(response).to be_successful
    end

    it 'renders the new template' do
      get new_survey_path
      expect(response).to render_template(:new)
    end

    it 'assigns a new survey with tienda' do
      get new_survey_path
      expect(assigns(:survey)).to be_a_new(Surveys::Survey)
      expect(assigns(:survey).tienda_id).to eq(tienda.id)
    end
  end

  describe 'GET /surveys' do
    let!(:survey1) { create(:survey, title: 'Survey 1', tienda: tienda, active: true) }
    let!(:survey2) { create(:survey, title: 'Survey 2', tienda: tienda, active: false) }
    let!(:survey_with_dates) { create(:survey, :with_date_range, title: 'Survey with Dates', tienda: tienda) }
    let!(:other_tienda_survey) { create(:survey, title: 'Other Survey', tienda: create(:tienda)) }

    it 'returns success' do
      get surveys_path
      expect(response).to be_successful
    end

    it 'shows surveys for current tienda only' do
      get surveys_path
      surveys = assigns(:surveys)
      expect(surveys).to include(survey1, survey2, survey_with_dates)
      expect(surveys).not_to include(other_tienda_survey)
    end

    it 'includes survey questions and responses in query' do
      create(:question, survey: survey1)
      get surveys_path

      # Should not cause N+1 queries due to includes in controller
      expect(assigns(:surveys).first.association(:questions)).to be_loaded
      expect(assigns(:surveys).first.association(:survey_responses)).to be_loaded
    end
  end

  describe 'GET /surveys/:id' do
    let!(:survey) { create(:survey, :with_questions, tienda: tienda) }

    it 'returns success' do
      get survey_path(survey)
      expect(response).to be_successful
    end

    it 'assigns the survey and total responses' do
      get survey_path(survey)
      expect(assigns(:survey)).to eq(survey)
      expect(assigns(:total_responses)).to eq(survey.total_responses)
    end
  end

  describe 'GET /surveys/:id/edit' do
    let!(:survey) { create(:survey, tienda: tienda) }

    it 'returns success' do
      get edit_survey_path(survey)
      expect(response).to be_successful
    end

    it 'assigns the survey' do
      get edit_survey_path(survey)
      expect(assigns(:survey)).to eq(survey)
    end
  end

  describe 'PUT /surveys/:id' do
    let!(:survey) { create(:survey, tienda: tienda) }

    context 'with valid parameters' do
      let(:new_attributes) do
        {
          title: 'Updated Survey Title',
          description: 'Updated description',
          fecha_desde: Date.current,
          fecha_hasta: 1.month.from_now.to_date
        }
      end

      it 'updates the survey' do
        put survey_path(survey), params: { survey: new_attributes }

        survey.reload
        expect(survey.title).to eq('Updated Survey Title')
        expect(survey.description).to eq('Updated description')
        expect(survey.fecha_desde).to eq(Date.current)
        expect(survey.fecha_hasta).to eq(1.month.from_now.to_date)
      end

      it 'redirects to the survey' do
        put survey_path(survey), params: { survey: new_attributes }
        expect(response).to redirect_to(survey_path(survey))
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        {
          title: '',
          fecha_desde: 2.weeks.from_now.to_date,
          fecha_hasta: 1.week.from_now.to_date
        }
      end

      it 'does not update the survey' do
        original_title = survey.title
        put survey_path(survey), params: { survey: invalid_attributes }

        survey.reload
        expect(survey.title).to eq(original_title)
      end

      it 'renders the edit template' do
        put survey_path(survey), params: { survey: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE /surveys/:id' do
    let!(:survey) { create(:survey, tienda: tienda) }

    it 'destroys the survey' do
      expect do
        delete survey_path(survey)
      end.to change(Surveys::Survey, :count).by(-1)
    end

    it 'redirects to surveys index' do
      delete survey_path(survey)
      expect(response).to redirect_to(surveys_path)
    end
  end

  describe 'Date range functionality' do
    context 'when creating survey with date range' do
      it 'correctly stores and displays date range' do
        start_date = Date.new(2025, 8, 1)
        end_date = Date.new(2025, 8, 31)

        post surveys_path, params: {
          survey: {
            title: 'August Survey',
            description: 'Survey for August',
            active: true,
            fecha_desde: start_date,
            fecha_hasta: end_date,
            questions_attributes: {
              '0' => {
                text: 'How do you rate this month?',
                question_type: 'text',
                required: false
              }
            }
          }
        }

        survey = Surveys::Survey.last
        expect(survey.fecha_desde).to eq(start_date)
        expect(survey.fecha_hasta).to eq(end_date)
        expect(survey.date_range_text).to eq('01/08/2025 - 31/08/2025')
      end
    end

    context 'when creating survey without date range' do
      it 'allows nil dates' do
        post surveys_path, params: {
          survey: {
            title: 'Unlimited Survey',
            description: 'Survey without date limits',
            active: true,
            fecha_desde: nil,
            fecha_hasta: nil,
            questions_attributes: {
              '0' => {
                text: 'What is your feedback?',
                question_type: 'text',
                required: false
              }
            }
          }
        }

        survey = Surveys::Survey.last
        expect(survey.fecha_desde).to be_nil
        expect(survey.fecha_hasta).to be_nil
        expect(survey.date_range_text).to eq('Sin límite de fechas')
        expect(survey.active_period?).to be true
      end
    end
  end
end
