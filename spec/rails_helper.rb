# Force test environment - do not read from anywhere else
ENV['RAILS_ENV'] = 'test'
require File.expand_path('../config/environment', __dir__)
require 'rspec/rails'

# Stagger parallel worker startup to avoid schema cache race conditions
# Each worker sleeps briefly so they don't all hit the DB schema at once
if ENV['TEST_ENV_NUMBER']
  worker_num = ENV['TEST_ENV_NUMBER'].to_i
  sleep(worker_num * 0.2) if worker_num > 0
end

# Required to use Selenium with Capybara
require 'capybara/rails'
require 'capybara/rspec'
require 'selenium-webdriver'

# Configure Capybara to use the remote Selenium server
Capybara.register_driver :selenium_remote do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  # Headless mode - controlled by HEADLESS_SELENIUM env var (default: true)
  # Set HEADLESS_SELENIUM=false to see the browser
  headless = ENV.fetch('HEADLESS_SELENIUM', 'true') != 'false'
  options.add_argument('--headless=new') if headless

  options.add_argument('--no-sandbox')
  # Removed --disable-dev-shm-usage to allow Chrome to use the 4GB shared memory
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1600,900')
  options.add_argument('--disable-web-security')
  options.add_argument('--allow-running-insecure-content')
  options.add_argument('--disable-features=VizDisplayCompositor')
  # Performance optimizations
  options.add_argument('--disable-extensions')
  options.add_argument('--disable-plugins')
  options.add_argument('--disable-images')
  options.add_argument('--disable-javascript-harmony-shipping')
  options.add_argument('--disable-background-timer-throttling')
  options.add_argument('--disable-renderer-backgrounding')
  options.add_argument('--disable-backgrounding-occluded-windows')
  # Explicitly use shared memory for better performance
  options.add_argument('--shm-size=4gb')

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: ENV.fetch('SELENIUM_HUB_URL', 'http://localhost:4444/wd/hub'),
    options: options
  )
end

# Configure Capybara basics
Capybara.configure do |config|
  config.always_include_port = true
  config.default_max_wait_time = 5 # Reduced from 10 to 5 seconds
  config.server_host = '0.0.0.0' # Allow Docker container access
  # Dynamic port for parallel tests - each worker gets unique port
  config.server_port = 3002 + ENV['TEST_ENV_NUMBER'].to_i
end

# Default driver setup
Capybara.default_driver = :rack_test
Capybara.javascript_driver = :selenium_remote

# Disable all screenshot functionality
Capybara.save_path = nil

# Prevent any ActionDispatch system test screenshots
if defined?(ActionDispatch::SystemTesting)
  ActionDispatch::SystemTesting::TestHelpers::ScreenshotHelper.module_eval do
    def take_screenshot
      # Screenshots disabled
    end

    def take_failed_screenshot
      # Screenshots disabled
    end
  end
end

# Don't set app_host - let Capybara auto-detect the server URL
# Capybara.app_host = "http://172.17.0.1:3002"

# Cache host IP once (doesn't change during a test run)
SELENIUM_HOST_IP = `ip route get 1.1.1.1 | awk '{print $7}' | head -1`.strip

# Debug Selenium configuration available via DEBUG_SELENIUM env var

# Requires supporting ruby files with custom matchers and macros, etc, in spec/support/ and its subdirectories.
Rails.root.glob('spec/support/**/*.rb').sort.each { |f| require f }

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures').to_s]
  config.use_transactional_fixtures = false # Changed to false for system tests
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  # If using FactoryBot:
  config.include FactoryBot::Syntax::Methods if defined?(FactoryBot)

  # Tag configuration for separating test types
  # Automatically tag system tests
  config.define_derived_metadata(file_path: %r{/spec/system/}) do |metadata|
    metadata[:type] = :system
    metadata[:js] = true
  end

  # Filter system tests by default unless explicitly requested
  config.filter_run_excluding type: :system unless ENV['SYSTEM_TESTS'] == 'true'

  # Allow running only system tests
  config.filter_run_including type: :system if ENV['ONLY_SYSTEM'] == 'true'

  # Disable screenshot functionality for system tests
  config.before(:each, type: :system) do
    # Override Rails system test screenshot methods to do nothing
    def take_screenshot
      # Disabled
    end

    def take_failed_screenshot
      # Disabled
    end

    # Also override Capybara page screenshot method
    if defined?(page)
      def page.save_screenshot(*args)
        # Screenshots disabled
      end
    end
  end

  # Force Capybara to use the remote Selenium driver for all system specs
  config.before(:each, type: :system) do
    driven_by :selenium_remote
    Capybara.app_host = "http://#{SELENIUM_HOST_IP}:#{Capybara.server_port}"
    Capybara.raise_server_errors = false
    Capybara.save_path = nil
  end

  # Clean up any alerts after each system test
  config.after(:each, type: :system) do
    alert = page.driver.browser.switch_to.alert
    alert.accept
  rescue Selenium::WebDriver::Error::NoSuchAlertError
    # No alert to handle
  ensure
    Capybara.reset_sessions!
  end

  # Use DatabaseCleaner to restore DB changes after each individual example (it/context)
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)

    # Create essential roles AFTER truncation
    # These are needed by Usuario model callbacks
    [
      { modulo: 'Usuarios', nombre: 'admin', titulo: 'Administrador' },
      { modulo: 'Usuarios', nombre: 'robot', titulo: 'Robot' },
      { modulo: 'Usuarios', nombre: 'comprador', titulo: 'Comprador' },
      { modulo: 'Usuarios', nombre: 'administrador_empresa', titulo: 'Administrador de Empresa Cliente' },
      { modulo: 'Productos', nombre: 'gestiona_productos', titulo: 'Gestiona Productos' }
    ].each do |attrs|
      Usuarios::Rol.find_or_create_by!(nombre: attrs[:nombre]) do |rol|
        rol.modulo = attrs[:modulo]
        rol.titulo = attrs[:titulo]
      end
    end
  end

  config.before do |example|
    DatabaseCleaner.strategy = if example.metadata[:type] == :system
                                 :deletion
                               else
                                 :transaction
                               end
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Authentication helpers for request specs
module AuthenticationHelpers
  def login_as(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:tienda_activa).and_return(user.visualizando_tienda)
    allow_any_instance_of(ApplicationController).to receive(:login_required).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:password_not_expired_required).and_return(true)
  end

  def bypass_authentication
    allow_any_instance_of(ApplicationController).to receive(:login_required).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:password_not_expired_required).and_return(true)
  end

  def bypass_authorization
    allow_any_instance_of(ApplicationController).to receive(:authorize!) do |controller, *_args|
      controller.instance_variable_set(:@_authorized, true)
    end
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
end
