require 'English'
namespace :parallel do
  desc 'Setup test databases for parallel runs (40 workers)'
  task setup: :environment do
    puts '🔧 Creating 40 test databases for parallel execution...'
    sh 'parallel_test -n 40 -e "rake db:create"'
    puts '📊 Loading structure into all test databases...'
    sh 'parallel_test -n 40 -e "rake db:structure:load"'
    puts '✅ Parallel test databases ready!'
  end

  desc 'Drop all parallel test databases'
  task drop: :environment do
    puts '🗑️  Dropping all parallel test databases...'
    sh 'parallel_test -n 40 -e "rake db:drop"'
    puts '✅ All test databases dropped!'
  end

  desc 'Recreate all parallel test databases'
  task recreate: [:drop, :setup]

  desc 'Run all specs in parallel (20 unit + 10 system workers)'
  task spec: :environment do
    puts '🚀 Running all specs (20 unit + 10 system workers)...'
    ENV['COVERAGE'] = 'true'
    isolated = 'spec/system/daily_orders_real_time_spec.rb spec/system/pedidos_cocina_spec.rb'

    # Unit tests: 20 workers
    sh 'parallel_rspec -n 20 --exclude-pattern "spec/system/**/*_spec.rb"'

    # System tests: 10 workers (isolated specs get their own single worker)
    sh "SYSTEM_TESTS=true parallel_rspec -n 10 --single #{isolated} spec/system/"

    puts "\n📊 Merging coverage results..."
    sh './bin/merge-coverage'
  end

  desc 'Run unit tests in parallel (20 workers)'
  task unit: :environment do
    puts '🧪 Running unit tests with 20 parallel workers...'
    ENV['COVERAGE'] = 'true'
    sh 'parallel_rspec -n 20 --exclude-pattern "spec/system/**/*_spec.rb"'
    puts "\n📊 Merging coverage results..."
    sh './bin/merge-coverage'
  end

  # Files that are flaky when parallelized (e.g., Action Cable WebSocket timing)
  isolated_system_specs = 'spec/system/daily_orders_real_time_spec.rb spec/system/pedidos_cocina_spec.rb'

  desc 'Run system tests in parallel (10 workers, flaky specs isolated via --single)'
  task system: :environment do
    puts '🌐 Running system tests with 10 parallel workers...'
    puts '   (isolated: daily_orders_real_time_spec.rb runs in a single worker)'
    ENV['COVERAGE'] = 'true'
    sh "SYSTEM_TESTS=true parallel_rspec -n 10 --single #{isolated_system_specs} spec/system/"
    puts "\n📊 Merging coverage results..."
    sh './bin/merge-coverage'
  end

  desc 'Run all tests with coverage (20 workers)'
  task coverage: :environment do
    puts '📊 Running all tests with coverage (20 workers)...'
    ENV['COVERAGE'] = 'true'
    sh 'parallel_rspec -n 20 spec/'
  end

  desc 'Run unit tests with coverage (20 workers)'
  task coverage_unit: :environment do
    puts '📊 Running unit tests with coverage (20 workers)...'
    ENV['COVERAGE'] = 'true'
    sh 'parallel_rspec -n 20 --exclude-pattern "spec/system/**/*_spec.rb"'
  end

  desc 'Run all tests with coverage including system (hybrid: 20 unit + 10 system)'
  task coverage_all: :environment do
    puts '📊 Running all tests with coverage (20 unit + 10 system workers)...'
    ENV['COVERAGE'] = 'true'
    start_time = Time.zone.now

    # Run unit tests first with 20 workers
    puts "\n#{'=' * 80}"
    puts '1️⃣  UNIT TESTS (20 workers)'.center(80)
    puts "#{'=' * 80}\n"

    unit_start = Time.zone.now
    unit_output = `parallel_rspec -n 20 --exclude-pattern "spec/system/**/*_spec.rb" 2>&1`
    puts unit_output
    unit_success = $CHILD_STATUS.success?
    unit_time = Time.zone.now - unit_start

    # Extract last line with example count
    unit_lines = unit_output.split("\n")
    unit_summary = unit_lines.reverse.find { |line| line =~ /\d+ examples?/ } || 'No results found'

    # Then run system tests with 10 workers
    puts "\n#{'=' * 80}"
    puts '2️⃣  SYSTEM TESTS (10 workers)'.center(80)
    puts "#{'=' * 80}\n"

    system_start = Time.zone.now
    system_output = `SYSTEM_TESTS=true parallel_rspec -n 10 --single #{isolated_system_specs} spec/system/ 2>&1`
    puts system_output
    system_success = $CHILD_STATUS.success?
    system_time = Time.zone.now - system_start

    # Extract last line with example count
    system_lines = system_output.split("\n")
    system_summary = system_lines.reverse.find { |line| line =~ /\d+ examples?/ } || 'No results found'

    total_time = Time.zone.now - start_time

    # Summary
    puts "\n#{'=' * 80}"
    puts '📊 FINAL SUMMARY'.center(80)
    puts '=' * 80
    puts "\n🧪 Unit Tests: #{unit_success ? '✅' : '❌'}"
    puts "   #{unit_summary}"
    puts "   ⏱️  Time: #{unit_time.round(1)}s"
    puts "\n🌐 System Tests: #{system_success ? '✅' : '❌'}"
    puts "   #{system_summary}"
    puts "   ⏱️  Time: #{system_time.round(1)}s"
    puts "\n⏱️  Total Time: #{total_time.round(1)}s (#{(total_time / 60).round(1)} minutes)"
    puts "\n#{'=' * 80}"

    # Exit with error if any tests failed
    exit(1) unless unit_success && system_success
  end

  desc 'Show parallel test runtime report'
  task runtime_log: :environment do
    sh 'cat tmp/parallel_runtime_rspec.log' if File.exist?('tmp/parallel_runtime_rspec.log')
  end

  desc 'Clean parallel test runtime log'
  task clean_runtime: :environment do
    sh 'rm -f tmp/parallel_runtime_rspec.log'
    puts '✅ Runtime log cleaned!'
  end

  namespace :docker do
    desc 'Start Selenium Grid with 20 Chrome nodes'
    task up: :environment do
      puts '🐳 Starting Selenium Grid with 20 Chrome nodes...'
      sh 'docker-compose -f docker-compose.parallel.yml up -d'
      puts '⏳ Waiting for Grid to be ready...'
      sleep 10
      puts '✅ Selenium Grid ready at http://localhost:4444'
      puts '📊 Grid Console: http://localhost:4444/ui'
      puts "\n🗄️  Ensuring 20 test databases exist..."

      # Create databases if they don't exist
      (1..20).each do |i|
        db_name = i == 1 ? 'kiosk_test' : "kiosk_test#{i}"
        sh "mysql -u root -h localhost -e \"CREATE DATABASE IF NOT EXISTS \\`#{db_name}\\` " \
           'CHARACTER SET latin1 COLLATE latin1_swedish_ci;" 2>/dev/null || true'
      end

      puts '✅ All test databases ready!'
    end

    desc 'Stop Selenium Grid'
    task down: :environment do
      puts '🛑 Stopping Selenium Grid...'
      sh 'docker-compose -f docker-compose.parallel.yml down'
      puts '✅ Selenium Grid stopped!'
    end

    desc 'Restart Selenium Grid'
    task restart: [:down, :up]

    desc 'Show Selenium Grid status'
    task status: :environment do
      sh 'docker-compose -f docker-compose.parallel.yml ps'
    end

    desc 'View Selenium Grid logs'
    task logs: :environment do
      sh 'docker-compose -f docker-compose.parallel.yml logs -f selenium-hub'
    end
  end
end

# Add shortcuts to quality namespace for consistency
namespace :quality do
  desc 'Run all tests in parallel (alias for parallel:spec)'
  task parallel: 'parallel:spec'

  desc 'Run all tests in parallel with coverage (alias for parallel:coverage_all)'
  task parallel_coverage: 'parallel:coverage_all'
end
