# rubocop:disable all
# bundler/capistrano was removed in Bundler 4.0 — inline bundle install task below

# Ruby 3.2+ removed Object#=~ — Capistrano v2 logger needs it on ServerDefinition
require 'capistrano/server_definition'
unless Capistrano::ServerDefinition.method_defined?(:=~)
  class Capistrano::ServerDefinition
    def =~(pattern)
      to_s =~ pattern
    end
  end
end

# Replaces bundler/capistrano functionality (must be before whenever/capistrano
# so this before-hook fires first in deploy:finalize_update callback chain)
namespace :bundle do
  task :install, roles: :app do
    run "cd #{release_path} && bundle config set --local deployment true && bundle config set --local quiet true && bundle config set --local force_ruby_platform true && bundle config set --local path #{shared_path}/bundle && bundle install"
  end
end
before 'deploy:finalize_update', 'bundle:install'

namespace :yarn do
  task :install, roles: :app do
    run "cp #{release_path}/package.json #{release_path}/yarn.lock #{shared_path}/ && cd #{shared_path} && yarn install --frozen-lockfile --production && rm -rf #{release_path}/node_modules && ln -s #{shared_path}/node_modules #{release_path}/node_modules"
  end
end
before 'deploy:assets:precompile', 'yarn:install'

set :whenever_command, 'bundle exec whenever'
require 'whenever/capistrano'

set :application, 'kiosk'
set :scm, 'git'
set :user, 'dev'
set :use_sudo, false
set :deploy_to, "/var/www/#{application}"
set :deploy_via, :remote_cache
set :repository, 'git@github.com:picocastillo/cateringsolutions.git'
default_run_options[:pty] = true

set :default_environment, 'PATH' => '$HOME/.asdf/shims:$HOME/.asdf/bin:$PATH'

desc 'deploy to the production environment'
task :production do
  set :domain, 'rosa'
  set :rails_env, 'production'
  set :branch, 'master'
  finalize
end

task :finalize do
  role :app, domain
  role :web, domain
  role :db,  domain, primary: true
end

def bundle_exec(cmd)
  run "cd #{current_path} && RAILS_ENV=production bundle exec #{cmd}"
end

after 'deploy:restart', 'deploy:cleanup'

namespace :deploy do
  task :make_links do
    run "ln -f #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "if [ -f #{shared_path}/config/master.key ]; then ln -f #{shared_path}/config/master.key #{release_path}/config/master.key; fi"
    run "mkdir -p #{release_path}/config/qz_tray && ln -f #{shared_path}/config/qz_tray/private-key.pem #{release_path}/config/qz_tray/private-key.pem"
  end
  after 'deploy:update_code', 'deploy:make_links'

  namespace :assets do
    desc 'Precompile assets with bundle exec'
    task :precompile, roles: :web do
      run "cd #{release_path} && RAILS_ENV=production RAILS_GROUPS=assets bundle exec rake assets:precompile"
    end
  end

  desc 'Run pending migrations with bundle exec'
  task :migrate, roles: :db, only: { primary: true } do
    run "cd #{release_path} && RAILS_ENV=production bundle exec rake db:migrate"
  end

  desc 'Restart Application'
  task :restart, roles: :app do
    run 'sudo systemctl restart puma-kiosk'
  end

  desc 'Kill Nailgun so Puma respawns it with the new release classpath'
  task :kill_nailgun, roles: :app do
    # Use [c] regex trick so pkill -f does not match its own command line
    run "pkill -f '[c]om.martiansoftware.nailgun.NGServer' || true"
  end
  before 'deploy:restart', 'deploy:kill_nailgun'

  desc 'Clear Rails cache'
  task :clear_cache, roles: :app do
    bundle_exec "rails runner 'Rails.cache.clear'"
  end
  after 'deploy:restart', 'deploy:clear_cache'
end

namespace :daemons do
  task :restart do
    stop
    start
  end

  task :stop do
    bundle_exec 'bin/delayed_job --queue=fast --pool=fast:3 --pid-dir=/tmp/fast_queue stop || true'
    bundle_exec 'bin/delayed_job --queue=slow --pool=slow:2 --pid-dir=/tmp/slow_queue stop || true'
    bundle_exec 'bin/delayed_job --queue=confirmacion --pool=confirmacion:2 --pid-dir=/tmp/confirmacion_queue stop || true'
    run 'rm -f /tmp/fast_queue/*.pid /tmp/slow_queue/*.pid /tmp/confirmacion_queue/*.pid'
  end

  task :start do
    bundle_exec 'bin/delayed_job --queue=fast --pool=fast:3 --pid-dir=/tmp/fast_queue start'
    bundle_exec 'bin/delayed_job --queue=slow --pool=slow:2 --pid-dir=/tmp/slow_queue start'
    bundle_exec 'bin/delayed_job --queue=confirmacion --pool=confirmacion:2 --pid-dir=/tmp/confirmacion_queue start'
  end

  task :quit do
    stop
  end

  task :status do
    bundle_exec 'bin/delayed_job --queue=fast --pool=fast:3 --pid-dir=/tmp/fast_queue status'
    bundle_exec 'bin/delayed_job --queue=slow --pool=slow:2 --pid-dir=/tmp/slow_queue status'
    bundle_exec 'bin/delayed_job --queue=confirmacion --pool=confirmacion:2 --pid-dir=/tmp/confirmacion_queue status'
  end

  after 'deploy:restart', 'daemons:restart'
end
