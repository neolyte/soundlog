require "test_helper"

class ProjectPennylaneInvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_path, params: { email: "roman@example.com", password: "password" }
  end

  test "links a Pennylane invoice to a project without creating duplicates" do
    remote_invoice = Pennylane::Invoice.new(
      id: "inv_2",
      number: "SL-002",
      public_file_url: nil
    )
    invoices_service = Class.new do
      define_method(:find) { |_id| remote_invoice }
    end
    original_new = Pennylane::Invoices.method(:new)
    Pennylane::Invoices.define_singleton_method(:new) { invoices_service.new }

    assert_difference -> { PennylaneInvoice.count }, 1 do
      assert_difference -> { ProjectPennylaneInvoice.count }, 1 do
        post project_pennylane_invoices_path(projects(:website)), params: { pennylane_invoice_remote_id: "inv_2" }
      end
    end

    assert_no_difference -> { ProjectPennylaneInvoice.count } do
      post project_pennylane_invoices_path(projects(:website)), params: { pennylane_invoice_remote_id: "inv_2" }
    end
  ensure
    Pennylane::Invoices.define_singleton_method(:new, original_new)
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
end
