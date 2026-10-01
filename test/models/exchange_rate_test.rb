require "test_helper"

class ExchangeRateTest < ActiveSupport::TestCase
  test "normalizes currency codes" do
    exchange_rate = ExchangeRate.create!(
      base_currency: "eur",
      quote_currency: " usd ",
      rate: 1.17,
      observed_on: Date.new(2026, 9, 30),
      source: "ECB"
    )

    assert_equal "EUR", exchange_rate.base_currency
    assert_equal "USD", exchange_rate.quote_currency
  end

  test "finds the latest rate for a currency pair" do
    older_rate = ExchangeRate.create!(
      base_currency: "EUR",
      quote_currency: "USD",
      rate: 1.10,
      observed_on: Date.new(2026, 9, 1),
      source: "ECB"
    )
    latest_rate = ExchangeRate.create!(
      base_currency: "EUR",
      quote_currency: "USD",
      rate: 1.20,
      observed_on: Date.new(2026, 9, 30),
      source: "ECB"
    )

    assert_equal latest_rate, ExchangeRate.latest_for("eur", "usd")
    assert_not_equal older_rate, ExchangeRate.latest_for("eur", "usd")
  end
end
