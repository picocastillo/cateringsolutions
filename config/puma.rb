# Threads: test uses 10 (parallel system tests), production/dev uses 5
default_threads = ENV.fetch('RAILS_ENV', 'development') == 'test' ? 10 : 5
threads_count = ENV.fetch('RAILS_MAX_THREADS', default_threads).to_i
threads threads_count, threads_count

environment ENV.fetch('RAILS_ENV') { 'development' }

# --- Production: clustered mode with Unix socket ---
# 5 workers x 5 threads = 25 concurrent requests
# Sized for an 8 vCPU / 8 GB box (workers ≈ cores - 3, leaving room for DJ + nailgun + DB)
# Action Cable WebSockets handled natively
if ENV.fetch('RAILS_ENV', 'development') == 'production'
  workers ENV.fetch('WEB_CONCURRENCY', 5).to_i
  preload_app!

  # Start Flying Saucer's nailgun JVM once in the master process before forking workers.
  # Without this, each worker independently detects nailgun isn't running and tries to start it,
  # causing slow PDF generation and race conditions on port 2113.
  before_fork do
    ActsAsFlyingSaucer::Config.setup_nailgun unless ActsAsFlyingSaucer::Config.nailgun_running?
  end

  bind 'unix:///var/www/kiosk/shared/tmp/sockets/puma.sock'
  pidfile '/var/www/kiosk/shared/tmp/pids/puma.pid'
  state_path '/var/www/kiosk/shared/tmp/pids/puma.state'

  stdout_redirect '/var/www/kiosk/shared/log/puma.stdout.log',
                  '/var/www/kiosk/shared/log/puma.stderr.log',
                  true

  on_worker_boot do
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  end
else
  # Development/test: TCP port
  port ENV.fetch('PORT', 3000)
end

plugin :tmp_restart
