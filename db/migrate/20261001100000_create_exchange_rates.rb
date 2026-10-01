require "bigdecimal"
require "yaml"

class CreateExchangeRates < ActiveRecord::Migration[8.0]
  def change
    create_table :exchange_rates do |t|
      t.string :base_currency, null: false
      t.string :quote_currency, null: false
      t.decimal :rate, precision: 20, scale: 10, null: false
      t.date :observed_on, null: false
      t.string :source

      t.timestamps
    end

    add_index :exchange_rates,
      [:base_currency, :quote_currency, :observed_on],
      unique: true,
      name: "index_exchange_rates_on_pair_and_observed_on"

    reversible do |direction|
      direction.up { import_existing_storage_rate }
    end
  end

  private

  def import_existing_storage_rate
    config_path = Rails.root.join("storage", "exchange_rates.yml")
    return unless config_path.exist?

    config = YAML.safe_load(config_path.read).presence || {}
    rate = BigDecimal(config["EUR_USD_RATE"].to_s)
    observed_on = Date.iso8601(config["EUR_USD_RATE_DATE"].to_s)
    return unless rate.positive?

    now = Time.current
    execute <<~SQL.squish
      INSERT INTO exchange_rates
        (base_currency, quote_currency, rate, observed_on, source, created_at, updated_at)
      VALUES
        (
          #{connection.quote("EUR")},
          #{connection.quote("USD")},
          #{connection.quote(rate.to_s("F"))},
          #{connection.quote(observed_on)},
          #{connection.quote(config["EUR_USD_RATE_SOURCE"].presence || "storage")},
          #{connection.quote(now)},
          #{connection.quote(now)}
        )
    SQL
  rescue ArgumentError, Psych::SyntaxError
    nil
  end
end
