module Pennylane
  class InvoiceMapper
    def self.map(payload)
      new(payload).to_invoice
    end

    def initialize(payload)
      @payload = payload
    end

    def to_invoice
      Invoice.new(
        id: value("id").to_s,
        number: value("invoice_number", "number", "label").to_s,
        public_file_url: value("public_file_url")
      )
    end

    private

    def value(*keys)
      keys.each do |key|
        return @payload[key] if @payload.key?(key)
      end

      nil
    end
  end
end
