app_name = ENV.fetch("APP_NAME", "soundlog")
root_directory = ENV.fetch("APP_ROOT", "/home/deploy/#{app_name}")

directory "#{root_directory}/current"
environment ENV.fetch("RAILS_ENV", "production")

tag app_name

pidfile     "#{root_directory}/shared/tmp/pids/puma.pid"
state_path  "#{root_directory}/shared/tmp/pids/puma.state"

# stdout_redirect(
#   "#{root_directory}/shared/log/puma_access.log",
#   "#{root_directory}/shared/log/puma_error.log",
#   true
# )

threads_count_min = ENV.fetch("PUMA_THREADS_MIN", 3).to_i
threads_count_max = ENV.fetch("PUMA_THREADS_MAX", 5).to_i
threads threads_count_min, threads_count_max

workers ENV.fetch("PUMA_WORKERS", 2).to_i

bind "unix://#{root_directory}/shared/tmp/sockets/puma.sock"

preload_app!

before_fork do
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.connection_pool.disconnect!
  end
end

before_worker_boot do
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.establish_connection
  end
end
