require 'rails_helper'

RSpec.describe 'Survey Responses', type: :system do
  let!(:tienda) { create(:tienda, carrito_de_compras: true, venta_mostrador: true) }
  let!(:admin) { create(:usuario, :admin, :with_password, visualizando_tienda: tienda) }

  # Create cliente user properly with matching tienda
  let!(:cliente_record) { create(:cliente, tienda: tienda) }
  let!(:cuenta) { create(:cuenta, cliente: cliente_record) }
  let!(:cliente) { create(:usuario, :cliente, :with_password, cuenta: cuenta, tienda_cliente: tienda, visualizando_tienda: tienda) }

  let!(:survey) { create(:survey, :with_questions, tienda: tienda) }

  context 'as an admin user' do
    before do
      admin_login(admin)
    end

    describe 'viewing survey responses' do
      let!(:completed_response) { create(:survey_response, :completed, survey: survey, user: cliente, tienda: tienda) }
      let!(:incomplete_response) { create(:survey_response, survey: survey, user: admin, tienda: tienda) }

      before do
        # Create some question responses for the completed response
        survey.questions.each do |question|
          create(:question_response,
                 survey_response: completed_response,
                 question: question,
                 response_text: 'Sample answer for question')
        end

        # Create partial responses for incomplete response
        create(:question_response,
               survey_response: incomplete_response,
               question: survey.questions.first,
               response_text: 'Partial answer')
      end

      it 'shows the survey responses index with statistics' do
        visit survey_survey_responses_path(survey)

        expect(page).to have_content(survey.title)
        expect(page).to have_content('Respuestas de la Encuesta')

        # Should show statistics cards
        expect(page).to have_content('Total Respuestas')
        expect(page).to have_content('2') # 2 responses total

        expect(page).to have_content('Preguntas')

        # Should show response list
        expect(page).to have_content(cliente.nombre)
        expect(page).to have_content(admin.nombre)

        # Should show progress information
        expect(page).to have_content('100%') # Completed response
        expect(page).to have_content('33%') # Incomplete response (1 of 3 questions)
      end

      it 'allows viewing individual response details' do
        visit survey_survey_responses_path(survey)

        # Click on the view button for the completed response
        within "tr[data-response-id='#{completed_response.id}']" do
          click_link 'Ver Detalles'
        end

        expect(page).to have_content('Información de la Respuesta')
        expect(page).to have_content(survey.title)
        expect(page).to have_content(cliente.nombre)
        expect(page).to have_content('Completa')
        expect(page).to have_content('100%')

        # Should show all question responses
        survey.questions.each do |question|
          expect(page).to have_content(question.text)
          expect(page).to have_content('Sample answer for question')
        end
      end

      it 'allows deleting responses', :js do
        visit survey_survey_responses_path(survey)

        # Should show 2 responses initially
        expect(page).to have_selector('tbody tr', count: 2)

        # Delete the incomplete response
        within "tr[data-response-id='#{incomplete_response.id}']" do
          # In test environment, JavaScript confirmations might not work
          # Let's just click the delete link directly
          click_link 'Eliminar'
        end

        # Should show success message and only 1 response remaining
        expect(page).to have_content('Respuesta eliminada exitosamente')
        expect(page).to have_selector('tbody tr', count: 1)
        expect(page).to have_content(cliente.nombre)
        expect(page).not_to have_content(admin.nombre)
      end
    end
  end

  context 'as a regular user' do
    before do
      cliente_login(cliente)
    end

    describe 'creating a survey response' do
      it 'allows filling out and submitting a survey', :js do
        # Regular users should go directly to the survey response form
        visit new_survey_survey_response_path(survey)

        # Should show survey response form
        expect(page).to have_content(survey.title)
        expect(current_path).to eq(new_survey_survey_response_path(survey))

        # Fill out the survey questions
        survey.questions.each_with_index do |question, index|
          case question.question_type
          when 'text'
            fill_in "response[#{question.id}]", with: "My answer to question #{index + 1}"
          when 'multiple_choice'
            choose "response_#{question.id}_#{question.answers.first.id}" if question.answers.any?
          when 'scale'
            choose "response_#{question.id}_3" # Choose rating 3
          end
        end

        # Submit the response
        click_button 'Enviar Respuestas'

        # Should redirect to pedidos page with success message (client users are redirected there)
        # Could be /pedidos/new or /pedidos/{id}/edit depending on existing pedidos
        expect(current_path).to match(%r{/pedidos})
        expect(page).to have_content('¡Gracias por completar la encuesta!')

        # Verify response was actually saved in database
        survey_response = survey.survey_responses.where(user: cliente).first
        expect(survey_response).to be_present
        expect(survey_response.question_responses.count).to be > 0
      end

      it 'shows validation errors for required questions' do
        # Clear any existing session state
        Capybara.reset_sessions!

        # Re-login the cliente user to ensure clean state
        cliente_login(cliente)

        # Create a survey with required questions
        required_survey = create(:survey, tienda: tienda)
        create(:question, :required, survey: required_survey, text: 'Required question')

        visit new_survey_survey_response_path(required_survey)

        # Submit without filling required field
        click_button 'Enviar Respuestas'

        # Should show validation errors
        expect(page).to have_content('Se encontraron errores')
        expect(page).to have_content('requerida')
      end

      it 'prevents duplicate responses from the same user' do
        # Create an existing response
        create(:survey_response, survey: survey, user: cliente, tienda: tienda)

        visit new_survey_survey_response_path(survey)

        # Should show message about already responding
        expect(page).to have_content('Ya has respondido esta encuesta')
      end
    end
  end

  context 'navigation and permissions' do
    it 'redirects non-admin users away from response management pages' do
      cliente_login(cliente)

      visit survey_survey_responses_path(survey)

      # Should redirect or show access denied
      expect(current_path).not_to eq(survey_survey_responses_path(survey))
    end

    it 'allows admin users to access response management' do
      admin_login(admin)

      visit survey_survey_responses_path(survey)

      expect(current_path).to eq(survey_survey_responses_path(survey))
      expect(page).to have_content('Respuestas de la Encuesta')
    end
  end
end
