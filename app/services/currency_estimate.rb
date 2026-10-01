class CurrencyEstimate
  TARGET_CURRENCY = "EUR"
  SOURCE_CURRENCY = "USD"
  RateDetails = Struct.new(:rate, :observed_on, :source, keyword_init: true)

  class << self
    def eur_total(totals_by_currency)
      totals = normalized_totals(totals_by_currency)
      return if totals.empty?
      rate = eur_usd_rate
      return if totals[SOURCE_CURRENCY].positive? && rate.blank?

      totals[TARGET_CURRENCY] + usd_to_eur(totals[SOURCE_CURRENCY], rate)
    end

    def relevant?(totals_by_currency)
      normalized_totals(totals_by_currency)[SOURCE_CURRENCY].positive?
    end

    def configured?
      eur_usd_rate.present?
    end

    def rate_label
      details = rate_details
      return unless details

      label = "EUR/USD #{details.rate.to_s("F")}"
      label = "#{label} from #{details.observed_on}" if details.observed_on.present?
      label = "#{label} (#{details.source})" if details.source.present?
      label
    end

    def eur_usd_rate
      rate_details&.rate
    end

    def rate_date
      rate_details&.observed_on&.to_s
    end

    def rate_source
      rate_details&.source
    end

    def reset!
      # Kept for older task/console callers. Rates are read fresh from the database.
    end

    private

    def normalized_totals(totals_by_currency)
      totals_by_currency.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |(currency, amount), totals|
        next if amount.blank?

        totals[currency.to_s.upcase] += amount.to_d
      end
    end

    def usd_to_eur(amount, rate)
      return BigDecimal("0") if amount.blank? || amount.to_d.zero?

      amount.to_d / rate
    end

    def env_rate?
      ENV["EUR_USD_RATE"].present?
    end

    def rate_details
      if env_rate?
        env_rate_details
      else
        database_rate_details
      end
    end

    def env_rate_details
      rate = decimal_value(ENV["EUR_USD_RATE"])
      return if rate.blank?

      RateDetails.new(
        rate:,
        observed_on: ENV["EUR_USD_RATE_DATE"].presence,
        source: ENV["EUR_USD_RATE_SOURCE"].presence
      )
    end

    def database_rate_details
      record = ExchangeRate.latest_for(TARGET_CURRENCY, SOURCE_CURRENCY)
      return if record.blank?

      RateDetails.new(
        rate: record.rate,
        observed_on: record.observed_on,
        source: record.source.presence
      )
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
