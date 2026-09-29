require "test_helper"

class ProjectPennylaneInvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_path, params: { email: "roman@example.com", password: "password" }
  end

  test "links a Pennylane invoice to a project without creating duplicates" do
    remote_invoice = Pennylane::Invoice.new(
      id: "inv_2",
      number: "SL-002",
      public_file_url: nil,
      amount: BigDecimal("1200.00"),
      currency: "EUR",
      date: Date.new(2026, 9, 10)
    )
    invoices_service = Class.new do
      define_method(:find) { |_id| remote_invoice }
    end.new

    with_pennylane_invoices_service(invoices_service) do
      assert_difference -> { PennylaneInvoice.count }, 1 do
        assert_difference -> { ProjectPennylaneInvoice.count }, 1 do
          post project_pennylane_invoices_path(projects(:website)), params: { pennylane_invoice_remote_id: "inv_2" }
        end
      end

      assert_no_difference -> { ProjectPennylaneInvoice.count } do
        post project_pennylane_invoices_path(projects(:website)), params: { pennylane_invoice_remote_id: "inv_2" }
      end
    end
  end

  test "unlinks only the Soundlog relationship" do
    link = project_pennylane_invoices(:linked)

    assert_difference -> { ProjectPennylaneInvoice.count }, -1 do
      assert_no_difference -> { PennylaneInvoice.count } do
        delete project_pennylane_invoice_path(projects(:website), link)
      end
    end
  end

  test "does not link invoices when Pennylane is disabled for the user" do
    delete logout_path
    post login_path, params: { email: "other@example.com", password: "password" }

    assert_no_difference -> { ProjectPennylaneInvoice.count } do
      post project_pennylane_invoices_path(projects(:other)), params: { pennylane_invoice_remote_id: "inv_2" }
    end

    assert_redirected_to project_path(projects(:other))
  end

  test "does not manage invoices when admin views a project whose owner has Pennylane disabled" do
    delete logout_path
    post login_path, params: { email: "admin@example.com", password: "password" }
    patch admin_view_mode_path, params: { mode: "all" }

    get project_pennylane_invoices_path(projects(:other))

    assert_redirected_to project_path(projects(:other))
  end

  test "opens a linked invoice with a fresh Pennylane PDF URL" do
    linked_invoice = pennylane_invoices(:sl_one)
    linked_invoice.update!(number: "Old number")
    previous_synced_at = linked_invoice.last_synced_at
    remote_invoice = Pennylane::Invoice.new(
      id: linked_invoice.remote_id,
      number: "SL-001",
      public_file_url: "https://example.test/fresh.pdf",
      amount: BigDecimal("1200.00"),
      currency: "EUR",
      date: Date.new(2026, 9, 10)
    )
    requested_ids = []
    invoices_service = Class.new do
      define_method(:find) do |id|
        requested_ids << id
        remote_invoice
      end
    end.new

    with_pennylane_invoices_service(invoices_service) do
      get pdf_project_pennylane_invoice_path(projects(:website), project_pennylane_invoices(:linked))
    end

    assert_equal ["inv_1"], requested_ids
    assert_redirected_to "https://example.test/fresh.pdf"
    assert_equal "SL-001", linked_invoice.reload.number
    assert_operator linked_invoice.last_synced_at, :>, previous_synced_at
  end

  test "does not leave Soundlog when Pennylane does not return a PDF URL" do
    linked_invoice = pennylane_invoices(:sl_one)
    remote_invoice = Pennylane::Invoice.new(
      id: linked_invoice.remote_id,
      number: "SL-001",
      public_file_url: nil,
      amount: BigDecimal("1200.00"),
      currency: "EUR",
      date: Date.new(2026, 9, 10)
    )
    invoices_service = Class.new do
      define_method(:find) { |_id| remote_invoice }
    end.new

    with_pennylane_invoices_service(invoices_service) do
      get pdf_project_pennylane_invoice_path(projects(:website), project_pennylane_invoices(:linked))
    end

    assert_redirected_to project_pennylane_invoices_path(projects(:website))
    assert_equal "Pennylane did not return a PDF link for this invoice", flash[:alert]
  end

  private

  def with_pennylane_invoices_service(service)
    original_new = Pennylane::Invoices.method(:new)
    Pennylane::Invoices.define_singleton_method(:new) { service }
    yield
  ensure
    Pennylane::Invoices.define_singleton_method(:new, original_new)
  end
end
