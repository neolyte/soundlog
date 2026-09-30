namespace :exchange_rates do
  desc "Fetch and store the latest ECB EUR/USD reference rate"
  task :eur_usd do
    on primary(:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :bundle, :exec, :rails, "exchange_rates:eur_usd"
        end
      end
    end
  end
end
