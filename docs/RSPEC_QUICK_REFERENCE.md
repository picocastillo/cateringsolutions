# RSpec Test Commands Quick Reference

## 🚀 Quick Commands

### Unit Tests (Fast - No Selenium)
```bash
bundle exec rspec                    # Default: unit tests only
rake quality:unit                    # Same as above
bundle exec rspec spec/models        # Specific folder
bundle exec rspec spec/models/pedidos/pedido_spec.rb  # Specific file
```

### System Tests (Selenium - Slower)
```bash
rake quality:system                  # All system tests
SYSTEM_TESTS=true bundle exec rspec spec/system/
SYSTEM_TESTS=true bundle exec rspec spec/system/stocks_spec.rb  # Specific file
```

### All Tests
```bash
rake quality:spec                    # All tests (unit + system)
SYSTEM_TESTS=true bundle exec rspec  # Same as above
```

## 📊 With Coverage

```bash
rake quality:coverage                # Unit tests with coverage
rake quality:coverage_all            # All tests with coverage
COVERAGE=true bundle exec rspec      # Unit tests with coverage
COVERAGE=true SYSTEM_TESTS=true bundle exec rspec  # All with coverage
```

## 🎯 Filtering

```bash
# By tag
bundle exec rspec --tag focus        # Run only focused tests
bundle exec rspec --tag ~slow        # Skip slow tests
bundle exec rspec --tag type:system  # Only system tests

# By pattern
bundle exec rspec --pattern 'spec/**/*_spec.rb'

# By example
bundle exec rspec spec/models/pedidos/pedido_spec.rb:42  # Line number
```

## 🔍 Output Formats

```bash
bundle exec rspec --format documentation  # Detailed
bundle exec rspec --format progress       # Dots
bundle exec rspec --format json           # JSON output
```

## 🐛 Debugging

```bash
bundle exec rspec --fail-fast            # Stop on first failure
bundle exec rspec --next-failure         # Run only next failing test
bundle exec rspec --only-failures        # Run only failed tests from last run
bundle exec rspec --seed 1234            # Use specific random seed
```

## 📋 Environment Variables

- `SYSTEM_TESTS=true` - Include system/selenium tests
- `ONLY_SYSTEM=true` - Run ONLY system tests
- `COVERAGE=true` - Generate coverage report
- `SELENIUM_HUB_URL` - Selenium hub URL (for Docker)

## 🏃 Development Workflow

### During Development (Fast)
```bash
bundle exec rspec spec/models/pedidos/  # Test specific area
```

### Before Commit (Medium)
```bash
rake quality                            # RuboCop + unit tests + coverage
```

### Before Push (Full)
```bash
rake quality:full                       # RuboCop + all tests + coverage
```

### Fixing Issues
```bash
bundle exec rubocop -A                  # Auto-fix style issues
bundle exec rspec --only-failures       # Rerun failed tests
```

## 📁 Test Types

- `spec/models/` - Unit tests (fast)
- `spec/requests/` - Request/controller tests (fast)
- `spec/system/` - End-to-end browser tests (slow, needs Selenium)
- `spec/support/` - Shared helpers and configurations

## 💡 Tips

1. **Default is fast**: Running `rspec` without flags skips Selenium tests
2. **System tests are opt-in**: Must use `SYSTEM_TESTS=true` to include them
3. **Use tags**: Tag slow tests and skip them during development
4. **Run specific tests**: Don't run the full suite every time
5. **Check coverage**: Run with `COVERAGE=true` periodically
