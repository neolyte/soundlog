module Pennylane
  class Paginator
    DEFAULT_LIMIT = 100

    def initialize(client:)
      @client = client
    end

    def get_all(path, query: {})
      records = []
      cursor = nil

      loop do
        page = @client.get(path, query: query.merge(limit: DEFAULT_LIMIT, cursor: cursor).compact)
        records.concat(Array(page["items"] || page["data"] || page["results"]))

        cursor = page["next_cursor"] || page.dig("pagination", "next_cursor")
        break unless cursor.present? && page.fetch("has_more", cursor.present?)
      end

      records
    end
  end
end
