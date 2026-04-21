# config/deploy.rb
set :user, :deploy
set :repo_url, "git@github.com:neolyte/soundlog.git"

set :rbenv_type, :user
set :rbenv_ruby, File.read('.ruby-version').strip

# Default value for linked_dirs
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "vendor", "public/system", ".bundle", "storage"

# Default value for linked_files
append :linked_files, "config/master.key"

namespace :deploy do
  namespace :check do
    before :linked_files, :set_master_key do
      on roles(:app), in: :sequence, wait: 10 do
        unless test("[ -f #{shared_path}/config/master.key ]")
          upload! "config/master.key", "#{shared_path}/config/master.key"
        end
      end
    end
  end
end
