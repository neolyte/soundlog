module Pennylane
  class Invoices
    CUSTOMER_INVOICES_PATH = "/customer_invoices"
    DEFAULT_SELECTOR_LIMIT = 100

    def initialize(client: Pennylane::Client.new)
      @client = client
    end

    def list_for_selector(query: nil, limit: DEFAULT_SELECTOR_LIMIT)
      invoices = first_page(limit: limit)
      query = query.to_s.strip.downcase
      return invoices if query.blank?

      invoices.select do |invoice|
        [
          invoice.number,
          invoice.id
        ].compact.any? { |value| value.to_s.downcase.include?(query) }
      end
    end

    def find(id)
      Pennylane::InvoiceMapper.map(@client.get("#{CUSTOMER_INVOICES_PATH}/#{id}"))
    end

    private

    def first_page(limit:)
      payload = @client.get(CUSTOMER_INVOICES_PATH, query: { filter: filters.to_json, sort: "-date", limit: limit })
      Array(payload["items"] || payload["data"] || payload["results"]).map do |invoice_payload|
        Pennylane::InvoiceMapper.map(invoice_payload)
      end
    end

    def filters
      [
        { field: "draft", operator: "eq", value: "false" },
        { field: "credit_note", operator: "eq", value: "false" }
      ]
    end
  end
end
