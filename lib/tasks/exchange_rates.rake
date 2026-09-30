require "fileutils"
require "net/http"
require "rexml/document"
require "yaml"

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

      observed_on = element.attributes["time"] if element.attributes["time"].present?
      if element.attributes["currency"] == CurrencyEstimate::SOURCE_CURRENCY
        eur_usd_rate = element.attributes["rate"]
      end
    end

    abort "ECB response did not include a USD reference rate" if eur_usd_rate.blank?

    config = {
      "EUR_USD_RATE" => eur_usd_rate,
      "EUR_USD_RATE_DATE" => observed_on,
      "EUR_USD_RATE_SOURCE" => "ECB"
    }.compact

    FileUtils.mkdir_p(CurrencyEstimate::CONFIG_PATH.dirname)
    CurrencyEstimate::CONFIG_PATH.write(config.to_yaml)
    CurrencyEstimate.reset!

    puts "Wrote #{CurrencyEstimate::CONFIG_PATH}"
    puts "EUR_USD_RATE=#{eur_usd_rate}"
    puts "EUR_USD_RATE_DATE=#{observed_on}" if observed_on.present?
    puts "EUR_USD_RATE_SOURCE=ECB"
  end
end
