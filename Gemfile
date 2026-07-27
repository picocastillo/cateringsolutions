source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.4.8'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'connection_pool', '~> 2.5'
gem 'mysql2', '~> 0.5'
gem 'rails', '~> 7.1.3'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Terser as compressor for JavaScript assets
gem 'afipws'
gem 'ar-enums', '~> 2.0'
gem 'terser'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'mini_racer', platforms: :ruby

gem 'dalli'
gem 'mimemagic', github: 'mimemagicrb/mimemagic', ref: '01f92d86d15d85cfd0f20dabd025dcbd36a8a60f'

# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
gem 'jwt'
# Use Redis adapter to run Action Cable in production
gem 'puma'
gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

gem 'activerecord-session_store'
gem 'acts_as_discontinued'
gem 'acts_as_flying_saucer', github: 'tanqueta/acts_as_flying_saucer', branch: 'better'
gem 'acts_as_list'
gem 'acts-as-taggable-on', '>= 7.0'
gem 'animate-rails'
gem 'attribute_normalizer', '~> 1.2.0'
gem 'barby'
gem 'bigdecimal'
gem 'bootstrap', '~> 4.3.1'
gem 'cancancan', '~> 3.6'
gem 'chunky_png'
gem 'config_spartan'
gem 'csv'
gem 'daemons'
gem 'danconia', git: 'https://github.com/tanqueta/danconia.git', branch: 'rails7'
gem 'default_value_for', '~> 4.1'
gem 'delayed_job', '~> 4.1.13'
gem 'delayed_job_active_record'
gem 'dropzonejs-rails'
gem 'exception_notification', '~> 4.0.1'
gem 'fcm'
gem 'font-awesome-rails'
gem 'jquery-fileupload-rails'
gem 'kt-paperclip'
gem 'material_design_icons', github: 'tanqueta/material_design_icons'
gem 'memoist'
gem 'mercadopago-sdk'
gem 'nailgun'
gem 'nested_form', github: 'tanqueta/nested_form', branch: 'customized'
gem 'net-smtp'
gem 'nprogress-rails'
gem 'ostruct'
gem 'roo', '~> 2.10'
gem 'simple_form'
gem 'sorted_set'
gem 'spreadsheet', '>= 0.7.1'
gem 'summernote-rails', '~> 0.8.12.0'
gem 'ulid'
gem 'virtus'
gem 'will_paginate', '>= 3.3.1'
gem 'write_xlsx'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development
gem 'capistrano', github: 'carloslopes/capistrano', branch: 'git-password-quotes'
gem 'whenever'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.1.0', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
  gem 'capybara', '3.39.2'
  gem 'database_cleaner-active_record'
  gem 'dotenv-rails'
  gem 'factory_bot_rails'
  gem 'parallel_tests'
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'rails-controller-testing'
  gem 'rspec-core', '~> 3.10'
  gem 'rspec-rails', '~> 6.0'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'selenium-webdriver', '~> 4.9.0'
  gem 'shoulda-matchers', '~> 4.0'
  gem 'simplecov', require: false
end

group :development do
  gem 'guard'
  gem 'guard-rspec', require: false
  gem 'ruby-lsp', require: false
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'listen'
  gem 'web-console'
end

group :test do
  gem 'faker'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:windows, :jruby]

gem 'bcrypt_pbkdf', '~> 1.1'
gem 'ed25519', '~> 1.3'
