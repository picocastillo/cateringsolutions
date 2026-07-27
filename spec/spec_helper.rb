# Force test environment - do not read from anywhere else
ENV['RAILS_ENV'] = 'test'

# SimpleCov must be loaded before application code
if ENV['COVERAGE'] == 'true'
  require 'simplecov'

  SimpleCov.start 'rails' do
    add_filter '/spec/'
    add_filter '/config/'
    add_filter '/vendor/'
    add_filter '/db/'

    add_group 'Controllers', 'app/controllers'
    add_group 'Models', 'app/models'
    add_group 'Queries', 'app/queries'
    add_group 'Services', 'app/services'
    add_group 'Jobs', 'app/jobs'
    add_group 'Mailers', 'app/mailers'
    add_group 'Helpers', 'app/helpers'
    add_group 'Forms', 'app/forms'
    add_group 'Validators', 'app/validators'
    add_group 'Gateways', 'app/gateways'

    # Set minimum coverage thresholds (lenient for existing codebase)
    # TODO: Gradually increase these as test coverage improves
    minimum_coverage 10
    minimum_coverage_by_file 0

    # Track files with zero coverage
    track_files '{app,lib}/**/*.rb'
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
