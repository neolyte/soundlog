require "test_helper"

class PennylaneInvoiceTest < ActiveSupport::TestCase
  test "caches identity and display metadata from a Pennylane invoice" do
    remote_invoice = Pennylane::Invoice.new(
      id: "inv_2",
      number: "SL-002",
      public_file_url: "https://example.test/invoice.pdf",
      amount: BigDecimal("1200.50"),
      currency: "EUR",
      date: Date.new(2026, 9, 10)
    )

    invoice = PennylaneInvoice.cache_from_remote!(remote_invoice)

    assert_equal "inv_2", invoice.remote_id
    assert_equal "SL-002", invoice.number
    assert_equal BigDecimal("1200.50"), invoice.amount
    assert_equal "EUR", invoice.currency
    assert_equal Date.new(2026, 9, 10), invoice.invoice_date
    assert invoice.last_synced_at.present?
  end
end
