module Pennylane
  class Invoices
    CUSTOMER_INVOICES_PATH = "/customer_invoices"
    DEFAULT_SELECTOR_LIMIT = 100
    REMOTE_ID_PATTERN = /\A(?:\d+|[a-z]+_[\w-]+)\z/i

    def initialize(client: Pennylane::Client.new)
      @client = client
    end

    def list_for_selector(query: nil, limit: DEFAULT_SELECTOR_LIMIT)
      invoices = first_page(limit: limit)
      query = query.to_s.strip
      return invoices if query.blank?

      normalized_query = query.downcase
      matches = invoices.select do |invoice|
        [
          invoice.number,
          invoice.id
        ].compact.any? { |value| value.to_s.downcase.include?(normalized_query) }
      end
      include_direct_invoice(matches, query) if remote_id_query?(query)
      matches
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

    def include_direct_invoice(matches, query)
      invoice = find(query)
      matches.unshift(invoice) unless matches.any? { |match| match.id == invoice.id }
    rescue Pennylane::RequestError
      nil
    end

    def remote_id_query?(query)
      query.match?(REMOTE_ID_PATTERN)
    end

    def filters
      [
        { field: "draft", operator: "eq", value: "false" },
        { field: "credit_note", operator: "eq", value: "false" }
      ]
    end
  end
end
