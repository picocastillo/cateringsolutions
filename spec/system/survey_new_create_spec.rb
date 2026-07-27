require 'rails_helper'

RSpec.describe 'Survey New and Create', :js, type: :system do
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
  end

  describe 'Survey New Page' do
    it 'displays the new survey form correctly' do
      # Login first
      admin_login(@admin_user)
      # Navigate to new survey page
      admin_login(@admin_user)
      admin_login(@admin_user)
      admin_login(@admin_user)
      admin_login(@admin_user)
      admin_login(@admin_user)
      admin_login(@admin_user)
      admin_login(@admin_user)
      admin_login(@admin_user)
      admin_login(@admin_user)
      admin_login(@admin_user)
      admin_login(@admin_user)
      admin_login(@admin_user)
      admin_login(@admin_user)
      visit new_survey_path

      # Check for helpful text
      expect(page).to have_field(placeholder: 'Ingrese el título de la encuesta')
      expect(page).to have_field(placeholder: 'Describa el propósito de la encuesta (opcional)')
      expect(page).to have_text('Opcional: fecha desde la cual estará disponible')
      expect(page).to have_text('Opcional: fecha hasta la cual estará disponible')

      # Check question placeholders
      within('.question-field', match: :first) do
        expect(page).to have_field(placeholder: 'Escriba su pregunta aquí')
      end
    end
  end
end
