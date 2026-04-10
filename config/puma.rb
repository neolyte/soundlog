# config/puma.rb
# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread pool size of Active Record.
#
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
#
port ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
#
environment ENV.fetch("RAILS_ENV") { "development" }

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker that has stopped responding.
#
worker_timeout 3600

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked web server processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers make copies of the application state as they are started, and share none
# by default. This load balancing is optimal for _stateless_ web applications, but
# may not be ideal for applications that cache data to the process store. See
# `preload_app!` option.
#
# Workers are forked web server processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers make copies of the application state as they are started, and share none
# by default. This load balancing is optimal for _stateless_ web applications, but
# may not be ideal for applications that cache data to the process store. Using
# preload_app will enable you to use copy on write friendly features.
#
# workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Use the `preload_app!` method when specifying a `workers` number to get
# increased performance from chdir-ing to the app directory when the server
# starts. In this setup, you may want to add a check in your `on_worker_boot`
# hook to only perform heavy initializations when booting a fresh Ruby process
# and not on every worker restart.
#
# preload_app!

# If you bind a UNIX socket instead of a TCP port, it will be defined in this block
# bind "unix://#{pidfile}.sock"

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart
