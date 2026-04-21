#!/usr/bin/env puma

app_name = "soundlog"
root_directory = "/home/deploy/#{app_name}"

directory "#{root_directory}/current"
rackup "#{root_directory}/current/config.ru"
environment "production"

tag app_name

pidfile "#{root_directory}/shared/tmp/pids/puma.pid"
state_path "#{root_directory}/shared/tmp/pids/puma.state"
stdout_redirect "#{root_directory}/shared/log/puma_access.log", "#{root_directory}/shared/log/puma_error.log", true

threads 4, 4

bind "unix://#{root_directory}/shared/tmp/sockets/puma.sock"

activate_control_app "unix://#{root_directory}/shared/tmp/sockets/pumactl.sock"

workers 1

restart_command "bundle exec puma"

preload_app!

on_restart do
  puts "Refreshing Gemfile"
  ENV["BUNDLE_GEMFILE"] = ""
end

before_fork do
  ActiveRecord::Base.connection_pool.disconnect!
end

on_worker_boot do
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.establish_connection
  end
end
