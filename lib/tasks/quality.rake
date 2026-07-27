namespace :quality do
  desc 'Run RuboCop to check code style'
  task rubocop: :environment do
    sh 'bundle exec rubocop'
  end

  desc 'Run RuboCop with auto-correct'
  task rubocop_fix: :environment do
    sh 'bundle exec rubocop -A'
  end

  desc 'Run unit tests only (excludes system/selenium tests)'
  task unit: :environment do
    sh 'bundle exec rspec --tag ~type:system'
  end

  desc 'Run system/selenium tests only'
  task system: :environment do
    ENV['SYSTEM_TESTS'] = 'true'
    ENV['ONLY_SYSTEM'] = 'true'
    sh 'bundle exec rspec --tag type:system'
  end

  desc 'Run all tests (unit + system)'
  task spec: :environment do
    ENV['SYSTEM_TESTS'] = 'true'
    sh 'bundle exec rspec'
  end

  desc 'Run unit tests with code coverage'
  task coverage: :environment do
    ENV['COVERAGE'] = 'true'
    sh 'bundle exec rspec --tag ~type:system'
  end

  desc 'Run all tests with code coverage (unit + system)'
  task coverage_all: :environment do
    ENV['COVERAGE'] = 'true'
    ENV['SYSTEM_TESTS'] = 'true'
    sh 'bundle exec rspec'
  end

  desc 'Run all quality checks (RuboCop + Unit tests with coverage)'
  task all: [:rubocop, :coverage] do
    puts "\n✅ All quality checks completed!"
  end

  desc 'Run complete quality checks (RuboCop + All tests with coverage)'
  task full: [:rubocop, :coverage_all] do
    puts "\n✅ Complete quality checks finished!"
  end

  desc 'Check coverage threshold'
  task check_coverage: :environment do
    require 'simplecov'
    require 'json'

    coverage_file = 'coverage/.last_run.json'
    unless File.exist?(coverage_file)
      puts "❌ No coverage data found. Run 'rake quality:coverage' first."
      exit 1
    end

    coverage_data = JSON.parse(File.read(coverage_file))
    coverage_percent = coverage_data.dig('result', 'line')

    if coverage_percent
      puts "📊 Current coverage: #{coverage_percent.round(2)}%"
      if coverage_percent >= 70
        puts '✅ Coverage threshold met!'
      else
        puts '⚠️  Coverage below 70% threshold'
        exit 1
      end
    else
      puts '❌ Could not read coverage percentage'
      exit 1
    end
  end
end

desc 'Run quality checks'
task quality: 'quality:all'
