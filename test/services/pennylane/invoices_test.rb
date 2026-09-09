require "test_helper"

module Pennylane
  class InvoicesTest < ActiveSupport::TestCase
    FakeClient = Struct.new(:responses, :requests) do
      def get(path, query: {})
        requests << [path, query]
        responses.shift
      end
    end

    test "lists customer invoices for selector with Pennylane filters" do
      client = FakeClient.new([
        {
          "items" => [
            {
              "id" => "inv_1",
              "invoice_number" => "SL-001",
              "public_file_url" => "https://example.test/invoice.pdf"
            }
          ],
          "has_more" => false
        }
      ], [])

      invoices = Pennylane::Invoices.new(client: client).list_for_selector(query: "SL-001")

      assert_equal ["inv_1"], invoices.map(&:id)
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
  end
end
