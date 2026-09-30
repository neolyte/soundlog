require "yaml"

class CurrencyEstimate
  TARGET_CURRENCY = "EUR"
  SOURCE_CURRENCY = "USD"
  CONFIG_PATH = Rails.root.join("storage", "exchange_rates.yml")

  class << self
    def eur_total(totals_by_currency)
      totals = normalized_totals(totals_by_currency)
      return if totals.empty?
      return if totals[SOURCE_CURRENCY].positive? && eur_usd_rate.blank?

      totals[TARGET_CURRENCY] + usd_to_eur(totals[SOURCE_CURRENCY])
    end

    def relevant?(totals_by_currency)
      normalized_totals(totals_by_currency)[SOURCE_CURRENCY].positive?
    end

    def configured?
      eur_usd_rate.present?
    end

    def rate_label
      return unless configured?

      label = "EUR/USD #{eur_usd_rate.to_s("F")}"
      label = "#{label} from #{rate_date}" if rate_date.present?
      label = "#{label} (#{rate_source})" if rate_source.present?
      label
    end

    def eur_usd_rate
      @eur_usd_rate ||= decimal_value(config_value("EUR_USD_RATE"))
    end

    def rate_date
      config_value("EUR_USD_RATE_DATE").presence
    end

    def rate_source
      config_value("EUR_USD_RATE_SOURCE").presence
    end

    def reset!
      @eur_usd_rate = nil
      @rate_config = nil
    end

    private

    def normalized_totals(totals_by_currency)
      totals_by_currency.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |(currency, amount), totals|
        next if amount.blank?

        totals[currency.to_s.upcase] += amount.to_d
      end
    end

    def usd_to_eur(amount)
      return BigDecimal("0") if amount.blank? || amount.to_d.zero?

      amount.to_d / eur_usd_rate
    end

    def config_value(name)
      return ENV[name].presence if env_rate?

      ENV[name].presence || rate_config[name].presence
    end

    def env_rate?
      ENV["EUR_USD_RATE"].present?
    end

    def rate_config
      @rate_config ||= begin
        if CONFIG_PATH.exist?
          YAML.safe_load(CONFIG_PATH.read).presence || {}
        else
          {}
        end
      rescue Psych::SyntaxError
        {}
      end
    end

    def decimal_value(value)
      raw_value = value.to_s.strip
      return if raw_value.blank?

      rate = BigDecimal(raw_value)
      rate.positive? ? rate : nil
    rescue ArgumentError
      nil
    end
  end
end
