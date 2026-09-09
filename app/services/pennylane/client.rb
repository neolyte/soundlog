require "net/http"
require "json"

module Pennylane
  class Client
    BASE_URL = "https://app.pennylane.com/api/external/v2"
    DEFAULT_TIMEOUT = 5

    def initialize(api_token: default_api_token, base_url: BASE_URL, timeout: DEFAULT_TIMEOUT)
      @api_token = api_token
      @base_url = base_url
      @timeout = timeout
    end

    def get(path, query: {})
      raise Pennylane::ConfigurationError, "Missing Pennylane API token" if @api_token.blank?

      uri = URI.join("#{@base_url}/", path.delete_prefix("/"))
      uri.query = query.to_query if query.present?

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@api_token}"
      request["Accept"] = "application/json"

      parse_response(perform(uri, request))
    end

    private

    def perform(uri, request)
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: @timeout, read_timeout: @timeout) do |http|
        http.request(request)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise Pennylane::TimeoutError, "Pennylane request timed out"
    rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET => error
      raise Pennylane::RequestError, error.message
    end

    def parse_response(response)
      body = response.body.presence || "{}"
      payload = JSON.parse(body)

      return payload if response.is_a?(Net::HTTPSuccess)

      raise Pennylane::RequestError, "Pennylane API returned #{response.code}: #{body.truncate(500)}"
    rescue JSON::ParserError
      raise Pennylane::RequestError, "Pennylane API returned invalid JSON"
    end

    def default_api_token
      ENV["PENNYLANE_API_TOKEN"].presence || Rails.application.credentials.dig(:pennylane, :api_token)
    end
  end
end
