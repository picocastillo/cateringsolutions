require 'rails_helper'

RSpec.describe 'SurveyResponses', type: :request do
  let(:tienda) { create(:tienda) }
  let(:admin_user) { create(:usuario, :admin, visualizando_tienda: tienda) }
  let(:regular_user) { create(:usuario, visualizando_tienda: tienda) }
  let(:survey) { create(:survey, :with_questions, tienda: tienda) }
  let(:survey_response) { create(:survey_response, survey: survey, user: regular_user) }

  describe 'GET /show' do
    context 'as admin user' do
      before { login_as(admin_user) }

      it 'returns http success' do
        get survey_survey_response_path(survey, survey_response)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET /index' do
    context 'as admin user' do
      before { login_as(admin_user) }

      it 'returns http success' do
        get survey_survey_responses_path(survey)
        expect(response).to have_http_status(:success)
      end
    end

    context 'as regular user' do
      before { login_as(regular_user) }

      it 'redirects non-admin user' do
        get survey_survey_responses_path(survey)
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'GET /new' do
    context 'as regular user' do
      before { login_as(regular_user) }

      it 'returns http success' do
        get new_survey_survey_response_path(survey)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /create' do
    context 'as regular user' do
      before { login_as(regular_user) }

      it 'returns http success' do
        post survey_survey_responses_path(survey), params: {
          response: { survey.questions.first.id.to_s => 'Test response' }
        }
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'PATCH /complete' do
    context 'as admin user' do
      before { login_as(admin_user) }

      it 'returns http success' do
        patch complete_survey_survey_response_path(survey, survey_response)
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
