source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# ruby "3.4.8"  # Read from .ruby-version file

# Core Rails
gem "rails", "~> 8.0.4"
gem "mysql2", "~> 0.5"
gem "puma", ">= 5.0"

# Frontend
gem "jbuilder"
gem "importmap-rails"
gem "propshaft"
gem "cssbundling-rails"
gem "turbo-rails"

# Authentication
gem "bcrypt", "~> 3.1.7"

# CSV export
gem "csv", "~> 3.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
end

group :development do
  # Reduces boot times through caching
  gem "bootsnap", ">= 1.1.0", require: false
  gem "web-console"
  gem "foreman"
  gem "capistrano", "~> 3.19", require: false
  gem "capistrano-rails", require: false
  gem "capistrano-bundler", require: false
  gem "capistrano3-puma", require: false
  gem "capistrano-faster-assets", require: false
end
