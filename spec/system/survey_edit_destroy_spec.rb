require 'rails_helper'

RSpec.describe 'Survey Edit and Destroy', type: :system do
  before do
    # Create a test clinic/tienda
    @tienda = create(:tienda,
                     nombre: 'Test Store',
                     dominio: 'localhost')

    # Create a test admin user (same pattern as working surveys_index_spec)
    @admin_user = create(:usuario,
                         login: 'admin',
                         password: 'password123',
                         password_confirmation: 'password123',
                         nombre: 'Admin User',
                         email: 'admin@example.com',
                         visualizando_tienda: @tienda,
                         tipo_usuario_id: 2) # Set admin type

    # Assign admin role
    admin_role = Usuarios::Rol.find_or_create_by(nombre: 'admin')
    @admin_user.roles << admin_role unless @admin_user.roles.include?(admin_role)

    # Create a test survey with questions
    @survey = create(:survey,
                     title: 'Encuesta Original',
                     description: 'Descripción original',
                     active: true,
                     tienda: @tienda)

    @question1 = create(:question,
                        survey: @survey,
                        text: '¿Pregunta original 1?',
                        question_type: 'text',
                        required: true)

    @question2 = create(:question,
                        survey: @survey,
                        text: '¿Pregunta original 2?',
                        question_type: 'multiple_choice',
                        required: false)
  end

  describe 'Survey Edit Page' do
    it 'displays the edit survey form correctly with existing data' do
      # Login first
      admin_login(@admin_user)

      # Go to edit page
      visit edit_survey_path(@survey)

      # Check that we're on the edit page
      expect(page).to have_text('Editar Encuesta')
      expect(page).to have_field('survey_title', with: @survey.title)
      expect(page).to have_field('survey_description', with: @survey.description)

      # Check that questions are displayed
      expect(page).to have_text(@question1.text)
      expect(page).to have_text(@question2.text)
    end
  end
end
