require "test_helper"

class CurrencyEstimateTest < ActiveSupport::TestCase
  RATE_ENV_KEYS = %w[EUR_USD_RATE EUR_USD_RATE_DATE EUR_USD_RATE_SOURCE].freeze

  setup do
    @previous_env = RATE_ENV_KEYS.to_h { |key| [key, ENV[key]] }
    RATE_ENV_KEYS.each { |key| ENV.delete(key) }
    ExchangeRate.delete_all
  end

  teardown do
    RATE_ENV_KEYS.each do |key|
      if @previous_env[key].nil?
        ENV.delete(key)
      else
        ENV[key] = @previous_env[key]
      end
    end
  end

  test "uses the latest database rate for USD estimates" do
    ExchangeRate.create!(
      base_currency: "EUR",
      quote_currency: "USD",
      rate: 1.50,
      observed_on: Date.new(2026, 9, 1),
      source: "ECB"
    )
    ExchangeRate.create!(
      base_currency: "EUR",
      quote_currency: "USD",
      rate: 1.20,
      observed_on: Date.new(2026, 9, 30),
      source: "ECB"
    )

    assert_equal BigDecimal("200.0"), CurrencyEstimate.eur_total("EUR" => 100, "USD" => 120)
    assert_equal "EUR/USD 1.2 from 2026-09-30 (ECB)", CurrencyEstimate.rate_label
  end

  test "returns nil for USD totals when no rate is configured" do
    assert_nil CurrencyEstimate.eur_total("USD" => 120)
    assert_equal BigDecimal("80.0"), CurrencyEstimate.eur_total("EUR" => 80)
  end

  test "environment rate overrides the database rate" do
    ExchangeRate.create!(
      base_currency: "EUR",
      quote_currency: "USD",
      rate: 1.00,
      observed_on: Date.new(2026, 9, 30),
      source: "ECB"
    )
    ENV["EUR_USD_RATE"] = "2.0"
    ENV["EUR_USD_RATE_DATE"] = "2026-10-01"
    ENV["EUR_USD_RATE_SOURCE"] = "Manual"

    assert_equal BigDecimal("1.0"), CurrencyEstimate.eur_total("USD" => 2)
    assert_equal "EUR/USD 2.0 from 2026-10-01 (Manual)", CurrencyEstimate.rate_label
  end
end
