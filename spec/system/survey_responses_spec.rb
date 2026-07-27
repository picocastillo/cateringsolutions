require 'rails_helper'

RSpec.describe 'Admin Survey Responses Management', :js, type: :system do
  before do
    # Create Comprobantes::Tipo records needed for billing system
    Comprobantes::Tipo.find_or_create_by(codigo: 1) do |tipo|
      tipo.desc = 'Factura'
      tipo.clase = 'Ventas::Facturacion::Factura'
      tipo.letra = 'A'
      tipo.debitan = false
    end

    Comprobantes::Tipo.find_or_create_by(codigo: 2) do |tipo|
      tipo.desc = 'Nota de Débito'
      tipo.clase = 'Ventas::Facturacion::NotaDebito'
      tipo.letra = 'A'
      tipo.debitan = true
    end
    @tienda = create(:tienda,
                     nombre: 'Test Store',
                     dominio: 'localhost',
                     carrito_de_compras: true, # Enable shopping cart functionality
                     venta_mostrador: true) # Enable counter sales

    # Create test users with proper credentials
    @admin_user = create(:usuario,
                         login: 'admin',
                         password: 'password123',
                         password_confirmation: 'password123',
                         nombre: 'Admin User',
                         email: 'admin@example.com',
                         visualizando_tienda: @tienda)

    # Create a cliente and cuenta for the test tienda (following cliente_login_spec pattern)
    @cliente = create(:cliente,
                      tienda: @tienda,
                      nombre: 'Test Cliente',
                      horarios_de_entrega: false,
                      usuario_puede_elegir_cuenta: false,
                      permitir_envios_a_domicilio: false,
                      cuenta_corriente: true)

    @cuenta = create(:cuenta,
                     nombre: 'Test Account',
                     cliente: @cliente)

    @cliente_user = create(:usuario, :cliente,
                           login: 'clienteuser',
                           password: 'password123',
                           password_confirmation: 'password123',
                           nombre: 'Cliente User',
                           email: 'cliente@example.com',
                           cuenta: @cuenta,
                           tienda_cliente: @tienda,
                           visualizando_tienda: @tienda)

    # Add admin role to admin user
    admin_rol = Usuarios::Rol.find_or_create_by(nombre: 'admin')
    @admin_user.roles << admin_rol unless @admin_user.roles.include?(admin_rol)

    # Create survey with questions
    @survey = create(:survey, :with_questions, tienda: @tienda)
  end

  context 'as an admin user' do
    before do
      admin_login(@admin_user)
    end

    describe 'viewing survey responses' do
      let!(:completed_response) { create(:survey_response, :completed, survey: @survey, user: @cliente_user, tienda: @tienda) }
      let!(:incomplete_response) { create(:survey_response, survey: @survey, user: @admin_user, tienda: @tienda) }

      before do
        # Create some question responses for the completed response
        @survey.questions.each do |question|
          create(:question_response,
                 survey_response: completed_response,
                 question: question,
                 response_text: 'Sample answer for question')
        end

        # Create partial responses for incomplete response
        create(:question_response,
               survey_response: incomplete_response,
               question: @survey.questions.first,
               response_text: 'Partial answer')
      end

      it 'shows the survey responses index with statistics' do
        visit survey_survey_responses_path(@survey)

        expect(page).to have_content(@survey.title)
        expect(page).to have_content('Respuestas de la Encuesta')

        # Should show statistics cards
        expect(page).to have_content('Total Respuestas')
        expect(page).to have_content('2') # 2 responses total

        expect(page).to have_content('Preguntas')

        # Should show response list
        expect(page).to have_content(@cliente_user.nombre)
        expect(page).to have_content(@admin_user.nombre)

        # Should show progress information
        expect(page).to have_content('100%') # Completed response
        expect(page).to have_content('33%') # Incomplete response (1 of 3 questions)
      end

      it 'allows viewing individual response details' do
        visit survey_survey_responses_path(@survey)

        # Click on the view button for the completed response
        within "tr[data-response-id='#{completed_response.id}']" do
          click_link 'Ver Detalles'
        end

        expect(page).to have_content('Respuesta de Cliente User')
        expect(page).to have_content(@survey.title)
        expect(page).to have_content(@cliente_user.nombre)
        expect(page).to have_content('Completada')
        expect(page).to have_content('100%')

        # Should show all question responses
        @survey.questions.each do |question|
          expect(page).to have_content(question.text)
          expect(page).to have_content('Sample answer for question')
        end
      end

      it 'allows deleting responses' do
        visit survey_survey_responses_path(@survey)

        # Should show 2 responses initially
        expect(page).to have_selector('tbody tr', count: 2)

        # Delete the incomplete response
        within "tr[data-response-id='#{incomplete_response.id}']" do
          click_link 'Eliminar'
        end

        # Should show success message and only 1 response remaining
        expect(page).to have_content('Respuesta eliminada exitosamente')
        expect(page).to have_selector('tbody tr', count: 1)
        expect(page).to have_content(@cliente_user.nombre)
        expect(page).not_to have_content(@admin_user.nombre)
      end
    end
  end

  context 'as a regular user' do
    before do
      cliente_login(@cliente_user)
    end

    describe 'creating a survey response' do
      it 'allows filling out and submitting a survey' do
        visit survey_path(@survey)

        # Should show survey details
        expect(page).to have_content(@survey.title)
        expect(page).to have_content('Responder Encuesta')

        # Click on respond button
        click_link 'Responder Encuesta'

        expect(current_path).to eq(new_survey_survey_response_path(@survey))
        expect(page).to have_content(@survey.title)

        # Fill out the survey questions
        @survey.questions.each_with_index do |question, index|
          case question.question_type
          when 'text'
            fill_in "response[#{question.id}]", with: "My answer to question #{index + 1}"
          when 'multiple_choice'
            choose "question_#{question.id}_answer_#{question.answers.first.id}" if question.answers.any?
          when 'scale'
            choose "response_#{question.id}_3" # Choose rating 3
          end
        end

        # Submit the response
        click_button 'Enviar Respuestas'

        # Debug: print the actual path to understand the routing

        # For client users, should redirect to pedidos with success message
        expect(page).to have_content('¡Gracias por completar la encuesta!')

        # Go back to survey to verify user has already responded
        visit survey_path(@survey)
        expect(page).to have_content('Ya has respondido esta encuesta')
        expect(page).not_to have_content('Responder Encuesta')
      end

      it 'shows validation errors for required questions' do
        # Create a survey with required questions using the empty trait to avoid default questions
        required_survey = create(:survey, :empty, tienda: @tienda)
        create(:question, :required, survey: required_survey, text: 'Required question')

        cliente_login(@cliente_user)
        visit new_survey_survey_response_path(required_survey)

        # Submit without filling required field
        click_button 'Enviar Respuestas'

        # When validation fails, Rails renders :new but the URL shows the POST path
        # Check for validation errors in the page content
        expect(page).to have_content('Se encontraron errores')
        expect(page).to have_content("La pregunta 'Required question' es requerida")
      end

      it 'prevents duplicate responses from the same user' do
        # Create an existing response
        create(:survey_response, survey: @survey, user: @cliente_user, tienda: @tienda)

        visit survey_path(@survey)

        # Should not show respond button
        expect(page).not_to have_content('Responder Encuesta')
        expect(page).to have_content('Ya has respondido esta encuesta')
      end
    end
  end

  context 'navigation and permissions' do
    it 'redirects non-admin users away from response management pages' do
      cliente_login(@cliente_user)

      visit survey_survey_responses_path(@survey)

      # Should show the specific error message from the controller
      expect(page).to have_content('No tienes acceso a la lista de respuestas.')
    end

    it 'allows admin users to access response management' do
      admin_login(@admin_user)

      visit survey_survey_responses_path(@survey)

      expect(current_path).to eq(survey_survey_responses_path(@survey))
      expect(page).to have_content('Respuestas de la Encuesta')
    end
  end
end
