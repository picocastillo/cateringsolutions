# Parallel Testing Guide

## Quick Start

### 1. Initial Setup (One-time)

```bash
./bin/setup-parallel-tests
```

This will:
- Install the `parallel_tests` gem
- Start Selenium Grid with 20 Chrome nodes
- Create 20 test databases (kiosk_test, kiosk_test2, ..., kiosk_test20)

### 2. Run Tests in Parallel

**All tests (20 workers):**
```bash
rake parallel:spec
```

**Unit tests only (20 workers):**
```bash
rake parallel:unit
```

**System tests only (10 workers):**
```bash
rake parallel:system
```

**All tests with coverage:**
```bash
rake parallel:coverage_all
```

## Docker Management

### Start Selenium Grid
```bash
rake parallel:docker:up
# or
docker-compose -f docker-compose.parallel.yml up -d
```

### Stop Selenium Grid
```bash
rake parallel:docker:down
# or
docker-compose -f docker-compose.parallel.yml down
```

### Check Grid Status
```bash
rake parallel:docker:status
# or visit http://localhost:4444/ui
```

### View Grid Logs
```bash
rake parallel:docker:logs
```

## Database Management

### Recreate test databases
```bash
rake parallel:recreate
```

### Manual database operations
```bash
# Create databases
parallel_test -n 20 -e "rake db:create"

# Load schema
parallel_test -n 20 -e "rake db:schema:load"

# Drop databases
rake parallel:drop
```

## Performance Comparison

### Before (Serial)
- **Total time**: ~11 minutes
- Unit tests: ~35 seconds
- System tests: ~10 minutes

### After (Parallel with 20 workers)
- **Total time**: ~1-2 minutes (est.)
- Unit tests: ~2 seconds (20x speedup)
- System tests: ~1 minute (10x speedup)

## Architecture

### Test Databases
- Each worker uses a separate database: `kiosk_test`, `kiosk_test2`, ..., `kiosk_test20`
- Database name determined by `TEST_ENV_NUMBER` environment variable
- Configuration in `config/database.yml`:
  ```yaml
  test:
    database: kiosk_test<%= ENV['TEST_ENV_NUMBER'] %>
  ```

### Selenium Grid
- **Hub**: Port 4444 (coordinates test distribution)
- **Nodes**: 20 Chrome nodes, each handles 2 concurrent sessions
- **Total capacity**: 40 concurrent browser sessions
- **Resource allocation**: 1.5GB RAM per node, 2GB shared memory

### Port Allocation
- Capybara server ports: 3002, 3003, 3004, ..., 3021
- Each test worker gets a unique port to avoid conflicts
- Configuration in `spec/rails_helper.rb`:
  ```ruby
  config.server_port = 3002 + (ENV['TEST_ENV_NUMBER'].to_i || 0)
  ```

## Troubleshooting

### Tests fail with database errors
```bash
# Recreate databases
rake parallel:recreate
```

### Selenium Grid not responding
```bash
# Restart the grid
rake parallel:docker:restart
```

### Out of memory errors
Reduce the number of workers:
```bash
# Use 10 workers instead of 20
parallel_rspec -n 10 spec/
```

### Check which tests are slow
```bash
# View runtime log
rake parallel:runtime_log
```

### Clean runtime cache
```bash
rake parallel:clean_runtime
```

## Configuration Files

- `docker-compose.parallel.yml` - Selenium Grid with 20 Chrome nodes
- `lib/tasks/parallel.rake` - Rake tasks for parallel execution
- `config/database.yml` - Database configuration with TEST_ENV_NUMBER support
- `spec/rails_helper.rb` - Capybara port configuration for parallel tests

## Resource Requirements

**Recommended System:**
- CPU: 16+ cores (you have 24 ✅)
- RAM: 32GB+ (20 Chrome nodes × 1.5GB each = 30GB)
- Disk: 10GB for test databases

**Current Configuration:**
- Using 20 workers for unit tests (CPU-bound)
- Using 10 workers for system tests (memory-bound)
- Total: ~18 cores average utilization

## Tips

1. **Run unit tests in parallel first** - they're faster and catch most issues
2. **System tests use fewer workers** - they're more resource-intensive
3. **Monitor with Grid Console** - http://localhost:4444/ui shows live test distribution
4. **Use coverage selectively** - it adds overhead, run without coverage for quick feedback

## CI/CD Integration

For CI environments, you can adjust worker count:

```bash
# On CI with fewer resources
parallel_rspec -n 4 spec/

# On powerful build servers
parallel_rspec -n 30 spec/
```

## Single Test Execution

To run tests normally (non-parallel):
```bash
# Use existing rake tasks
rake quality:spec
rake quality:coverage

# Or run RSpec directly
bundle exec rspec spec/
```
