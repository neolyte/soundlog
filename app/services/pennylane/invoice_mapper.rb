module Pennylane
  class InvoiceMapper
    def self.map(payload)
      new(payload).to_invoice
    end

    def initialize(payload)
      @payload = payload
    end

    def to_invoice
      currency = normalized_currency

      Invoice.new(
        id: value("id").to_s,
        number: value("invoice_number", "number", "label").to_s,
        public_file_url: value("public_file_url"),
        amount: invoice_amount(currency),
        currency:,
        date: date_value("date")
      )
    end

    private

    def value(*keys)
      keys.each do |key|
        return @payload[key] if @payload.key?(key)
      end

      nil
    end

    def normalized_currency
      value("currency").to_s.upcase.presence
    end

    def invoice_amount(currency)
      decimal_value("currency_amount") || (decimal_value("amount") if currency.blank? || currency == "EUR")
    end

    def decimal_value(*keys)
      raw_value = value(*keys)
      return if raw_value.blank?

      BigDecimal(raw_value.to_s)
    rescue ArgumentError
      nil
    end

    def date_value(*keys)
      raw_value = value(*keys)
      return if raw_value.blank?

      Date.iso8601(raw_value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
