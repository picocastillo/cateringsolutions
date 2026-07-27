module SystemTestHelpers
  # System test authentication helper
  def sign_in_as(usuario)
    # For system tests, we need to actually navigate and simulate user interaction
    visit login_path if respond_to?(:login_path)

    # If there's no login page, we'll use controller mocking
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(usuario)
    allow_any_instance_of(ApplicationController).to receive(:tienda_activa).and_return(usuario.visualizando_tienda)
    allow_any_instance_of(ApplicationController).to receive(:login_required).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:password_not_expired_required).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:authorize!).and_return(true)
  end

  # Helper for admin login in system specs
  def admin_login(admin_user, password = 'password123')
    visit '/'

    # Check if already logged in (would redirect to /inicio)
    return if current_path == '/inicio'

    expect(page).to have_field('username')
    expect(page).to have_field('password')

    fill_in 'username', with: admin_user.login
    fill_in 'password', with: password

    page.find('button[type="submit"], input[type="submit"]', match: :first).click

    expect(page).to have_current_path('/inicio', wait: 10, ignore_query: true)
  end

  # Helper for regular user login in system specs
  def user_login(user, password = 'password123')
    visit '/'

    # Check if already logged in
    return if current_path != '/'

    expect(page).to have_field('username')
    expect(page).to have_field('password')

    fill_in 'username', with: user.login
    fill_in 'password', with: password

    page.find('button[type="submit"], input[type="submit"]', match: :first).click

    expect(page).not_to have_current_path('/', wait: 10)
  end

  # Helper for cliente user login in system specs
  def cliente_login(cliente_user, password = 'password123')
    visit '/'

    # Check if already logged in
    return if current_path != '/'

    expect(page).to have_field('username')
    expect(page).to have_field('password')

    fill_in 'username', with: cliente_user.login
    fill_in 'password', with: password

    page.find('button[type="submit"], input[type="submit"]', match: :first).click

    expect(page).not_to have_current_path('/', wait: 10)
    expect(current_path).to match(%r{/pedidos})
  end

  # Helper to wait for page to load completely
  def wait_for_page_load
    expect(page).to have_css('body')
  end

  # Helper to accept confirmation dialogs
  def accept_confirmation_dialog
    page.driver.browser.switch_to.alert.accept
  rescue Selenium::WebDriver::Error::NoSuchAlertError
    # No alert present, continue
  end

  # Helper to fill in date fields (handles different date input formats)
  def fill_in_date(field, with:)
    # Try different approaches for date inputs

    fill_in field, with: with.strftime('%Y-%m-%d')
  rescue StandardError
    # If that fails, try with the date as string
    fill_in field, with: with.to_s
  end

  # Helper to wait for AJAX requests to complete
  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until page.evaluate_script('jQuery.active == 0')
    end
  rescue StandardError
    # Fallback if jQuery is not available
    sleep(0.5)
  end

  # Helper to scroll element into view
  def scroll_to(element)
    script = 'arguments[0].scrollIntoView(true);'
    page.driver.browser.execute_script(script, element.native)
  end

  # Helper to select from a dropdown by text
  def select_option(text, from:)
    select text, from: from
  rescue Capybara::ElementNotFound
    # Try with different selector
    find("select[name='#{from}']").select(text)
  end
end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system

  # Screenshot functionality disabled
  # config.before(:suite) do
  #   FileUtils.mkdir_p('tmp/screenshots') if defined?(Capybara)
  # end

  # Screenshot on failure disabled
  config.after(:each, type: :system) do |_example|
    # Intentionally empty - screenshots disabled
  end
end
