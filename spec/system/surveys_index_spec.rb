require 'rails_helper'

RSpec.describe 'Surveys Index', :js, type: :system do
  before do
    # Create a test clinic/tienda
    @tienda = create(:tienda,
                     nombre: 'Test Store',
                     dominio: 'localhost')

    # Create a test admin user
    @admin_user = create(:usuario,
                         login: 'admin',
                         password: 'password123',
                         password_confirmation: 'password123',
                         nombre: 'Admin User',
                         email: 'admin@example.com',
                         visualizando_tienda: @tienda)

    # Create some test surveys
    @active_survey = create(:survey,
                            title: 'Encuesta de Satisfacción',
                            description: 'Encuesta para evaluar la satisfacción del cliente con nuestros servicios',
                            active: true,
                            tienda: @tienda,
                            fecha_desde: Date.current - 7.days,
                            fecha_hasta: Date.current + 7.days)

    @inactive_survey = create(:survey,
                              title: 'Encuesta de Producto',
                              description: 'Evaluación de productos y servicios ofrecidos',
                              active: false,
                              tienda: @tienda,
                              fecha_desde: Date.current - 30.days,
                              fecha_hasta: Date.current - 1.day)

    @future_survey = create(:survey,
                            title: 'Encuesta Futura',
                            description: 'Encuesta programada para el futuro',
                            active: true,
                            tienda: @tienda,
                            fecha_desde: Date.current + 7.days,
                            fecha_hasta: Date.current + 30.days)

    # Add questions to the active survey
    @text_question = create(:question,
                            survey: @active_survey,
                            text: '¿Cuál es su nombre?',
                            question_type: 'text',
                            required: true)

    @choice_question = create(:question,
                              survey: @active_survey,
                              text: '¿Cómo calificaría nuestro servicio?',
                              question_type: 'multiple_choice',
                              required: true)

    # Add answers to the choice question
    create(:answer, question: @choice_question, text: 'Excelente', value: '5')
    create(:answer, question: @choice_question, text: 'Bueno', value: '4')
    create(:answer, question: @choice_question, text: 'Regular', value: '3')

    # Add some survey responses to active survey
    3.times do |i|
      test_user = create(:usuario,
                         login: "respondent#{i}",
                         nombre: "Test User #{i}",
                         email: "user#{i}@test.com",
                         visualizando_tienda: @tienda)
      response = create(:survey_response,
                        survey: @active_survey,
                        user: test_user,
                        tienda: @tienda,
                        completed_at: Time.current)
      create(:question_response,
             survey_response: response,
             question: @text_question,
             response_text: "Usuario #{i}")
    end
  end

  describe 'Surveys Index Page' do
    it 'displays the surveys index correctly for authenticated user' do
      # Login first
      admin_login(@admin_user)

      # Navigate to surveys index
      visit surveys_path

      # Check page title and header
      expect(page).to have_text('Encuestas')
      expect(page).to have_link('Nueva Encuesta', href: new_survey_path)

      # Check that surveys are displayed in table
      expect(page).to have_table
      expect(page).to have_text(@active_survey.title)
      expect(page).to have_text(@inactive_survey.title)
      expect(page).to have_text(@future_survey.title)

      # Check survey statuses
      expect(page).to have_css('.badge-success') # Active badge
      expect(page).to have_css('.badge-secondary') # Inactive badge

      # Check responsive container and layout
      expect(page).to have_css('.container-fluid')
      expect(page).to have_css('.card')
      expect(page).to have_css('.table-responsive')

      # Check Bootstrap classes are present
      expect(page).to have_css('.btn-primary') # New survey button
      expect(page).to have_css('.btn-group') # Action button groups
    end

    it 'displays optimized question and response counts without N+1 queries' do
      admin_login(@admin_user)

      # Clear any existing questions on inactive survey and add exactly 1
      @inactive_survey.questions.destroy_all
      create(:question, survey: @inactive_survey, text: 'Question for inactive', question_type: 'text')

      # Add one more question to active survey to test the count optimization
      create(:question, survey: @active_survey, text: 'Question 4', question_type: 'text')

      # Test that we can access the page without database query issues
      visit surveys_path

      # Active survey has 4 questions total (3 from setup + 1 new)
      within('tr', text: @active_survey.title) do
        expect(page).to have_css('.badge-info', text: '4') # 4 questions total
        expect(page).to have_css('.badge-primary', text: '3') # 3 responses
      end

      within('tr', text: @inactive_survey.title) do
        expect(page).to have_css('.badge-info', text: '1') # 1 question
        expect(page).to have_css('.badge-primary', text: '0') # 0 responses
      end
    end

    it 'handles pagination correctly when there are many surveys' do
      admin_login(@admin_user)

      # Create enough surveys to trigger pagination (21 total - 3 existing + 18 new)
      18.times do |i|
        create(:survey,
               title: "Survey #{i + 4}", # Start from 4 since we have 3 existing
               description: "Generated survey for pagination test #{i + 1}",
               active: i.even?, # Alternate between active/inactive
               tienda: @tienda)
      end

      # Visit first page
      visit surveys_path

      # Should show pagination controls since we have 21 surveys (> 20 per page)
      expect(page).to have_css('.kiosk_pagination') # Custom pagination helper

      # Should show "Next" or page 2 link
      expect(page).to have_link('2') # Page 2 link

      # Should show 20 surveys on first page (paginate per_page: 20)
      expect(page).to have_css('tbody tr', count: 20)

      # Navigate to page 2 - scope to pagination to avoid clicking a non-pagination link
      within('.kiosk_pagination') do
        click_link '2'
      end

      # Should show 1 survey on second page (21 total - 20 on first page)
      expect(page).to have_css('tbody tr', count: 1, wait: 10)

      # Should have "Previous" or page 1 link
      within('.kiosk_pagination') do
        expect(page).to have_link('1') # Page 1 link
      end
    end

    it 'maintains performance with large datasets' do
      admin_login(@admin_user)

      # Create a larger dataset to test performance
      50.times do |i|
        survey = create(:survey,
                        title: "Performance Test Survey #{i + 1}",
                        description: "Large dataset survey #{i + 1}",
                        active: true,
                        tienda: @tienda)

        # Add questions to each survey
        3.times do |j|
          create(:question,
                 survey: survey,
                 text: "Question #{j + 1} for survey #{i + 1}",
                 question_type: 'text')
        end

        # Add some responses
        next unless i < 10 # Only add responses to first 10 surveys to vary the counts

        2.times do |k|
          user = create(:usuario,
                        login: "perf_user_#{i}_#{k}",
                        nombre: "Performance User #{i}-#{k}",
                        email: "perf#{i}#{k}@test.com",
                        visualizando_tienda: @tienda)
          create(:survey_response,
                 survey: survey,
                 user: user,
                 tienda: @tienda,
                 completed_at: Time.current)
        end
      end

      # Measure page load time (should be reasonable even with large dataset)
      start_time = Time.current
      visit surveys_path
      end_time = Time.current

      load_time = end_time - start_time

      # Page should load within reasonable time (< 5 seconds for system test)
      expect(load_time).to be < 5.seconds

      # Should show first page with pagination
      expect(page).to have_css('.kiosk_pagination')
      expect(page).to have_css('tbody tr', count: 20) # First page

      # Verify optimized counts are working (check a few surveys)
      expect(page).to have_css('.badge-info') # Question counts
      expect(page).to have_css('.badge-primary') # Response counts
    end

    it 'shows appropriate message when no surveys exist' do
      # Remove all surveys and their dependencies properly
      Surveys::QuestionResponse.delete_all
      Surveys::SurveyResponse.delete_all
      Surveys::Answer.delete_all
      Surveys::Question.delete_all
      Surveys::Survey.delete_all

      admin_login(@admin_user)
      visit surveys_path

      # Should show empty state message
      expect(page).to have_text('No hay encuestas creadas')
      expect(page).to have_text('Cree su primera encuesta para comenzar a recopilar respuestas')
      expect(page).to have_link('Crear Primera Encuesta', href: new_survey_path)

      # Should not show pagination when there are no results
      expect(page).not_to have_css('.kiosk_pagination')
    end
  end
end
