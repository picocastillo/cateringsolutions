require_relative 'boot'

# Only require the Rails frameworks we actually use (skip ActionMailbox/ActionMailer conflicts with ar-enums)
require 'rails'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'active_job/railtie'
require 'action_cable/engine'
# require 'action_mailbox/engine'  # Not used, conflicts with ar-enums
# require 'action_text/engine'     # Not used
require 'rails/test_unit/railtie'
require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Kiosk
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    config.autoload_paths += ["#{config.root}/lib"]
    config.autoload_paths += ["#{config.root}/app/services"]
    config.autoload_paths += ["#{config.root}/app/controllers/concerns"]

    require_relative '../app/middleware/metricas_logger'
    config.middleware.insert_after ActionDispatch::RequestId, MetricasLogger
    # config.action_controller.permit_all_parameters = true
    config.time_zone = 'Buenos Aires'
    config.active_record.default_timezone = :local
    config.active_record.index_nested_attribute_errors = true
    config.assets.image_optim = false

    # Store uploaded files on the local file system (see config/storage.yml for options)
    config.active_storage.service = :local

    # Pasar a una queue de prioridad media
    config.action_mailer.deliver_later_queue_name = 'fast'
    config.action_mailer.asset_host = 'http://localhost:3000'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.enforce_available_locales = false
    config.i18n.default_locale = 'es-AR'

    config.generators do |g|
      g.assets false
      g.helper false
      g.view_specs false
      g.helper_specs false
      g.controller_specs false
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Configure Redis cache store for all environments
    redis_database = case Rails.env
                     when 'production'
                       0
                     when 'test'
                       2
                     else # development and any other environment
                       1
                     end

    redis_host = ENV['REDIS_HOST'] || 'localhost'
    redis_port = ENV['REDIS_PORT'] || 6379

    config.cache_store = :redis_cache_store, {
      url: "redis://#{redis_host}:#{redis_port}/#{redis_database}",
      connect_timeout: 30,
      read_timeout: 0.3,
      write_timeout: 0.3,
      reconnect_attempts: 3,
      error_handler: lambda { |_method:, _returning:, exception:|
        Rails.logger.error "Redis cache error: #{exception.class}: #{exception.message}"
      }
    }
  end
end

ExceptionSender = %{"Catering (#{Rails.env})" <app.error.#{Rails.env}@cateringsolutions.com.ar>}.freeze
ExceptionRecipients = ['sebachavarini@gmail.com'].freeze
