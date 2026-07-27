# Skill: Running Tests

## MANDATORY PROCEDURE — Follow EXACTLY every time

### When user asks to "run tests" (no schema/migration changes)

**Step 1: Check Docker is running** (one command)
```bash
docker.exe compose -f docker-compose.parallel.yml ps 2>&1 | head -5
```
- If 13+ containers are Up → go to Step 2
- If containers are down or missing → run:
```bash
docker.exe compose -f docker-compose.parallel.yml up -d 2>&1 && sleep 15
```

**Step 2: Run the tests** (one command)
```bash
./bin/ptest unit      # unit only (~44s)
./bin/ptest system    # system only (~3min)
./bin/ptest all       # unit + system (~4min)
```
Pick based on what user asked. Default to `unit` unless they specifically say "all" or "system".

That's it. TWO steps. Do NOT manually call `parallel_rspec`, `rake parallel:*`, or rebuild databases.

---

### When user asks to "reset and run tests" OR after schema/migration changes

**One command — covers everything:**
```bash
./bin/reset-and-test unit       # reset + unit only
./bin/reset-and-test system     # reset + system only
./bin/reset-and-test all        # reset + unit + system
./bin/reset-and-test coverage   # reset + all + coverage (default)
```

This script handles: Docker restart → MariaDB wait → structure.sql dump → 20 DB rebuild → Selenium check → test run.

---

### NEVER DO ANY OF THESE

- **NEVER** call `parallel_rspec` directly — use `./bin/ptest`
- **NEVER** manually rebuild databases unless `./bin/reset-and-test` fails
- **NEVER** call `rake parallel:spec` or `rake parallel:unit` — use `./bin/ptest`
- **NEVER** run `bundle exec rspec` for the full suite — always use parallel
- **NEVER** loop through databases manually — `./bin/reset-and-test` handles it
- **NEVER** dump `structure.sql` manually — `./bin/reset-and-test` handles it

---

## Quick Reference

| What user says | Command |
|---|---|
| "run tests" / "run unit tests" | `./bin/ptest unit` |
| "run system tests" | `./bin/ptest system` |
| "run all tests" | `./bin/ptest all` |
| "reset and run tests" / after migrations | `./bin/reset-and-test all` |
| "run with coverage" | `./bin/ptest coverage` |

## Architecture Details (for debugging only)

### Components

| Component | Details |
|---|---|
| Test Runner | `parallel_tests` gem via `./bin/ptest` wrapper |
| Unit Workers | 20 parallel processes |
| System Workers | 10 parallel processes |
| Selenium Grid | Hub + 10 Chrome nodes (2 sessions each = 20 slots) |
| Docker Compose | `docker-compose.parallel.yml` (MariaDB + Redis + Selenium) |
| Databases | 20 test DBs: `kiosk_test`, `kiosk_test2`...`kiosk_test20` |
| Charset | `latin1 / latin1_swedish_ci` (NOT utf8mb4) |
| Port Allocation | 3002 + TEST_ENV_NUMBER |
| Coverage | SimpleCov auto-merges from all workers |

### Key Files

| File | Purpose |
|---|---|
| `bin/ptest` | **THE** test runner — all test commands go through here |
| `bin/reset-and-test` | Full reset + run (Docker, DBs, structure.sql, tests) |
| `docker-compose.parallel.yml` | Selenium Grid + MariaDB + Redis |
| `lib/tasks/parallel.rake` | Rake task definitions (called by bin scripts) |
| `spec/rails_helper.rb` | Capybara config, DatabaseCleaner, driver setup |
| `spec/spec_helper.rb` | SimpleCov config |
| `.parallelrc` | parallel_tests default worker count |

### Isolated (Flaky) Specs

These specs run in a single worker via `--single` flag to avoid parallel interference:
- `spec/system/daily_orders_real_time_spec.rb` (Action Cable timing)
- `spec/system/pedidos_cocina_spec.rb` (shared state)

Defined in both `bin/ptest` (ISOLATED_SPECS variable) and `lib/tasks/parallel.rake` (isolated_system_specs).

### DatabaseCleaner Strategy

- Unit tests: `:transaction` (fast rollback)
- System tests: `:deletion` (required — browser runs in separate process)

### Troubleshooting

| Problem | Solution |
|---|---|
| Docker not found | Start Docker Desktop, wait 60s, retry |
| MariaDB not ready | `mysql -u root -pmysqlroot -h 127.0.0.1 -P 3306 -e "SELECT 1"` |
| Selenium Grid not ready | `curl -s http://localhost:4444/status` — wait 15s after container start |
| `pesable_changed?` errors | Stale DB schema — run `./bin/reset-and-test` |
| Tests pass individually but fail parallel | Usually stale DBs — run `./bin/reset-and-test` |
| System tests skipped | `SYSTEM_TESTS=true` must be set (automatic with `./bin/ptest system`) |
| Port 4444 busy | `docker.exe compose -f docker-compose.parallel.yml down` then `up -d` |
| Unknown column errors | Schema changed — run `./bin/reset-and-test` |
