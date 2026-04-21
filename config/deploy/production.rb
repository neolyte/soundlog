# config/deploy/production.rb
# Set PRODUCTION_SERVER_HOST in your shell or deploy environment.
server ENV.fetch("PRODUCTION_SERVER_HOST"), user: "deploy", roles: %w{web app db}, primary: true, ssh_options: { keepalive: true, keepalive_interval: 60 }

set :default_env, {
  "PATH" => "/home/deploy/.nvm/versions/node/v18.20.6/bin:$PATH"
}

set :application, "soundlog"
set :deploy_to, "/home/deploy/#{fetch(:application)}"
set :rails_env, "production"

set :branch, "main"  # Change if using different branch

# Puma systemd configuration
set :puma_systemctl_user, :system
set :puma_service_unit_name, "puma_#{fetch(:application)}"
