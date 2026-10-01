require "net/http"
require "rexml/document"

namespace :exchange_rates do
  desc "Fetch and store the latest ECB EUR/USD reference rate for EUR estimates"
  task eur_usd: :environment do
    uri = URI("https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")
    response = Net::HTTP.get_response(uri)
    unless response.is_a?(Net::HTTPSuccess)
      abort "ECB request failed with HTTP #{response.code}"
    end

    document = REXML::Document.new(response.body)
    observed_on = nil
    eur_usd_rate = nil

    document.each_recursive do |element|
      next unless element.name == "Cube"

      observed_on = Date.iso8601(element.attributes["time"]) if element.attributes["time"].present?
      if element.attributes["currency"] == CurrencyEstimate::SOURCE_CURRENCY
        eur_usd_rate = element.attributes["rate"]
      end
    end

    abort "ECB response did not include an observation date" if observed_on.blank?
    abort "ECB response did not include a USD reference rate" if eur_usd_rate.blank?

    exchange_rate = ExchangeRate.find_or_initialize_by(
      base_currency: CurrencyEstimate::TARGET_CURRENCY,
      quote_currency: CurrencyEstimate::SOURCE_CURRENCY,
      observed_on:
    )
    exchange_rate.assign_attributes(rate: eur_usd_rate, source: "ECB")
    exchange_rate.save!
    CurrencyEstimate.reset!

    puts "Stored #{CurrencyEstimate::TARGET_CURRENCY}/#{CurrencyEstimate::SOURCE_CURRENCY} exchange rate ##{exchange_rate.id}"
    puts "EUR_USD_RATE=#{eur_usd_rate}"
    puts "EUR_USD_RATE_DATE=#{observed_on}"
    puts "EUR_USD_RATE_SOURCE=ECB"
  end
end
