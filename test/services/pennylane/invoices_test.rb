require "test_helper"

module Pennylane
  class InvoicesTest < ActiveSupport::TestCase
    FakeClient = Struct.new(:responses, :requests) do
      def get(path, query: {})
        requests << [path, query]
        response = responses.shift
        raise response if response.is_a?(StandardError)

        response
      end
    end

    test "lists customer invoices for selector with Pennylane filters" do
      client = FakeClient.new([
        {
          "items" => [
            {
              "id" => "inv_1",
              "invoice_number" => "SL-001",
              "public_file_url" => "https://example.test/invoice.pdf",
              "currency_amount" => "230.32",
              "currency" => "EUR",
              "date" => "2026-09-10"
            }
          ],
          "has_more" => false
        }
      ], [])

      invoices = Pennylane::Invoices.new(client: client).list_for_selector(query: "SL-001")

      assert_equal ["inv_1"], invoices.map(&:id)
      assert_equal BigDecimal("230.32"), invoices.first.amount
      assert_equal "EUR", invoices.first.currency
      assert_equal Date.new(2026, 9, 10), invoices.first.date
      assert_equal "/customer_invoices", client.requests.first.first
      assert_includes client.requests.first.second[:filter], "\"draft\",\"operator\":\"eq\",\"value\":\"false\""
      assert_includes client.requests.first.second[:filter], "\"credit_note\",\"operator\":\"eq\",\"value\":\"false\""
      assert_equal "-date", client.requests.first.second[:sort]
      assert_equal 100, client.requests.first.second[:limit]
    end

    test "finds an invoice by remote id" do
      client = FakeClient.new([
        { "id" => "inv_1", "invoice_number" => "SL-001" }
      ], [])

      invoice = Pennylane::Invoices.new(client: client).find("inv_1")

      assert_equal "SL-001", invoice.number
      assert_equal "/customer_invoices/inv_1", client.requests.first.first
    end

    test "includes exact remote id matches outside the selector first page" do
      client = FakeClient.new([
        {
          "items" => [
            {
              "id" => "recent_1",
              "invoice_number" => "SL-RECENT"
            }
          ],
          "has_more" => true
        },
        {
          "id" => "30276923961344",
          "invoice_number" => "SL-OLD"
        }
      ], [])

      invoices = Pennylane::Invoices.new(client: client).list_for_selector(query: "30276923961344")

      assert_equal ["30276923961344"], invoices.map(&:id)
      assert_equal "/customer_invoices", client.requests.first.first
      assert_equal "/customer_invoices/30276923961344", client.requests.second.first
    end

    test "keeps selector matches when a numeric query is not a remote id" do
      client = FakeClient.new([
        {
          "items" => [
            {
              "id" => "inv_302",
              "invoice_number" => "SL-302"
            }
          ],
          "has_more" => false
        },
        Pennylane::RequestError.new("Pennylane API returned 404: {}")
      ], [])

      invoices = Pennylane::Invoices.new(client: client).list_for_selector(query: "302")

      assert_equal ["inv_302"], invoices.map(&:id)
      assert_equal "/customer_invoices/302", client.requests.second.first
    end
  end
end
