# config/deploy/staging.rb
# Optional: configure only if you have a staging server
set :server_ip, "your.staging.server.ip"

server fetch(:server_ip), user: "deploy", roles: %w{web app db}, primary: true, ssh_options: { keepalive: true, keepalive_interval: 60 }

set :application, "soundlog-staging"
set :deploy_to, "/home/deploy/#{fetch(:application)}"
set :rails_env, "staging"

set :branch, "develop"

# Puma systemd configuration
set :puma_systemctl_user, :system
set :puma_service_unit_name, "puma_#{fetch(:application)}"
