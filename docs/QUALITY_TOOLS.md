# Code Quality Tools

This project uses RuboCop for code style checking and SimpleCov for test coverage analysis.

## Setup

Install the gems:

```bash
bundle install
```

## RuboCop (Code Style & Syntax)

### Check code style
```bash
bundle exec rubocop
```

### Auto-fix issues
```bash
bundle exec rubocop -A
```

### Check specific files
```bash
bundle exec rubocop app/models/pedidos/pedido.rb
```

### Check specific cops
```bash
bundle exec rubocop --only Layout/LineLength
```

### Configuration
- `.rubocop.yml` - Main configuration file
- Configured for Rails 5.2 and Ruby 2.7.4
- Includes rubocop-rails and rubocop-rspec plugins

## SimpleCov (Code Coverage)

### Run tests with coverage
```bash
COVERAGE=true bundle exec rspec
```

### View coverage report
After running tests with coverage, open:
```
coverage/index.html
```

### Configuration
- `.simplecov` - SimpleCov configuration
- Minimum coverage threshold: 70%
- Minimum per-file coverage: 50%
- Excludes: spec/, config/, vendor/, db/

## Rake Tasks

### Run all quality checks (RuboCop + Unit tests with coverage)
```bash
rake quality
# or
rake quality:all
```

### Run complete quality checks (RuboCop + All tests with coverage)
```bash
rake quality:full
```

### Run only RuboCop
```bash
rake quality:rubocop
```

### Run RuboCop with auto-fix
```bash
rake quality:rubocop_fix
```

### Run unit tests only (fast - excludes Selenium)
```bash
rake quality:unit
```

### Run system/Selenium tests only
```bash
rake quality:system
```

### Run all tests (unit + system)
```bash
rake quality:spec
```

### Run unit tests with coverage
```bash
rake quality:coverage
```

### Run all tests with coverage (unit + system)
```bash
rake quality:coverage_all
```

### Check if coverage meets threshold
```bash
rake quality:check_coverage
```

## Running Tests Separately

### Unit Tests Only (Fast)
```bash
# Using rake
## Test Organization

By default:
- **`bundle exec rspec`** - Runs only unit tests (fast)
- **System tests are excluded** - Must be explicitly enabled
- **Use environment variables** - `SYSTEM_TESTS=true` to include them

This separation allows:
- **Fast feedback** - Run unit tests during development
- **Full validation** - Run system tests before deployment
- **Parallel execution** - Run test types separately in CI/CD

## Tips

1. **During development**: Run `rake quality:unit` for fast feedback
2. **Before committing**: Run `rake quality` (RuboCop + unit tests)
3. **Before pushing**: Run `rake quality:full` (includes system tests)
4. **Auto-fix safe issues**: Use `rubocop -A` for automatic fixes
5. **Focus on new code**: RuboCop can check only changed files with `--only-changed`
6. **Coverage trends**: Check coverage/index.html regularly to track improvement
7. **Disable cops selectively**: Use `# rubocop:disable CopName` only when necessary
8. **Selenium tests**: Run separately with `rake quality:system` to avoid slowdowns
```

### System/Selenium Tests Only
```bash
# Using rake
rake quality:system

# Using rspec directly
SYSTEM_TESTS=true ONLY_SYSTEM=true bundle exec rspec --tag type:system

# Or specific file
SYSTEM_TESTS=true bundle exec rspec spec/system/stocks_spec.rb
```

### All Tests Together
```bash
# Using rake
rake quality:spec

# Using rspec directly
SYSTEM_TESTS=true bundle exec rspec
```

## Coverage Groups

SimpleCov organizes coverage by:
- Controllers
- Models
- Queries
- Services
- Jobs
- Mailers
- Helpers
- Forms
- Validators
- Gateways

## CI/CD Integration

Add to your CI pipeline:

```yaml
# Example for GitHub Actions
- name: Run RuboCop
  run: bundle exec rubocop

- name: Run RSpec with coverage
  run: COVERAGE=true bundle exec rspec

- name: Check coverage threshold
  run: rake quality:check_coverage
```

## Tips

1. **Before committing**: Run `rake quality` to catch issues early
2. **Auto-fix safe issues**: Use `rubocop -A` for automatic fixes
3. **Focus on new code**: RuboCop can check only changed files with `--only-changed`
4. **Coverage trends**: Check coverage/index.html regularly to track improvement
5. **Disable cops selectively**: Use `# rubocop:disable CopName` only when necessary

## RuboCop Quick Reference

Common cops:
- `Layout/LineLength` - Max 120 characters
- `Metrics/MethodLength` - Max 25 lines
- `Metrics/ClassLength` - Max 150 lines
- `Style/StringLiterals` - Use single quotes
- `Rails/HasManyOrHasOneDependent` - Disabled (legacy code)

## Excluding Files

To exclude files from RuboCop, add to `.rubocop.yml`:
```yaml
AllCops:
  Exclude:
    - 'path/to/file.rb'
```

To exclude from coverage, add to `.simplecov`:
```ruby
SimpleCov.start 'rails' do
  add_filter '/path/to/exclude/'
end
```
