namespace :db do
  namespace :test do
    desc 'Custom: Drop, create and load schema for test database (kiosk_test)'
    task setup: :environment do
      # Force test environment
      ENV['RAILS_ENV'] = 'test'
      Rails.env = 'test'

      # Load Rails environment for database configuration
      require_relative '../../config/environment'

      # Get the test database configuration
      config = ActiveRecord::Base.configurations['test']
      database_name = config['database']

      puts "Setting up test database: #{database_name}"

      # Create a MySQL connection without specifying database for drop/create operations
      admin_config = {
        host: config['host'],
        username: config['username'],
        password: config['password'],
        port: config['port'] || 3306
      }

      begin
        # Connect to MySQL without specifying database
        connection = Mysql2::Client.new(admin_config)

        # Drop the test database if it exists
        puts "Dropping database #{database_name}..."
        begin
          connection.query("DROP DATABASE IF EXISTS `#{database_name}`")
          puts "Database #{database_name} dropped successfully."
        rescue StandardError => e
          puts "Error dropping database #{database_name}: #{e.message}"
        end

        # Create the test database
        puts "Creating database #{database_name}..."
        connection.query("CREATE DATABASE `#{database_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
        puts "Database #{database_name} created successfully."

        connection.close
      rescue StandardError => e
        puts "Error with MySQL connection: #{e.message}"
        raise e
      end

      # Load the schema
      begin
        puts "Loading schema into #{database_name}..."

        # Clear connections and establish fresh connection to the test database
        ActiveRecord::Base.clear_all_connections!
        ActiveRecord::Base.establish_connection(:test)

        # Load the schema.rb file
        schema_file = Rails.root.join('db/schema.rb')
        if File.exist?(schema_file)
          load(schema_file)
          puts "Schema loaded successfully into #{database_name}."
        else
          puts "Warning: schema.rb file not found at #{schema_file}"
        end
      rescue StandardError => e
        puts "Error loading schema into #{database_name}: #{e.message}"
        raise e
      end

      puts 'Test database setup completed successfully!'
    end

    # Override the default prepare task to use our custom setup
    task prepare: :setup

    desc 'Setup test database and run specs'
    task spec: :environment do
      Rake::Task['db:test:setup'].invoke
      puts "\n#{'=' * 50}"
      puts 'Running RSpec tests...'
      puts "#{'=' * 50}\n"
      system('RAILS_ENV=test bundle exec rspec')
    end
  end
end
