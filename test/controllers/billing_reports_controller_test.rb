require "test_helper"

class BillingReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_path, params: { email: "roman@example.com", password: "password" }
  end

  test "shows the selected billing month" do
    get billing_path(month: "2026-09")

    assert_response :success
    assert_select "h1", "Billing Report"
    assert_select ".projects-period-nav__label", "September 2026"
  end

  test "shows a billing category breakdown" do
    get billing_category_path("invoiceable", month: "2026-09")

    assert_response :success
    assert_select "h1", "Invoiceable Breakdown"
    assert_select "a", "View entries"
  end

  test "archived quoted projects keep invoice revenue only in the invoice month" do
    project = projects(:website)
    project.update!(billing_treatment: "quoted_fixed")
    pennylane_invoices(:sl_one).update!(amount: 1500, currency: "EUR", invoice_date: Date.new(2026, 9, 30))
    TimeEntry.create!(project:, user: users(:roman), date: Date.new(2026, 10, 1), hours: 2, status: "unbilled")

    get root_path(billing_month: "2026-09")
    assert_response :success
    assert_select ".billing-breakdown__item", text: /Quoted\/fixed/ do
      assert_select "strong", "1,500 €"
    end

    project.update!(active: false)

    get root_path(billing_month: "2026-09")
    assert_response :success
    assert_select ".billing-breakdown__item", text: /Quoted\/fixed/ do
      assert_select "strong", "1,500 €"
    end

    get billing_path(month: "2026-09")
    assert_response :success
    assert_select ".billing-breakdown__item", text: /Quoted\/fixed/ do
      assert_select "strong", "1,500.00 €"
    end

    get billing_category_path("quoted_fixed", month: "2026-09")
    assert_response :success
    assert_select ".billing-detail-row", 1
    assert_select ".billing-detail-row__main strong", "SL-001"
    assert_select ".billing-detail-row__project-link[href=?]", project_path(project)
    assert_select ".billing-detail-card__total strong", "1,500.00 €"

    %w[2026-08 2026-10 2027-01].each do |month|
      get billing_category_path("quoted_fixed", month:)
      assert_response :success
      assert_select ".billing-detail-row", 0
      assert_select ".billing-detail-card__total strong", "-"
    end
  end

  test "quoted invoice revenue survives archiving the client" do
    projects(:website).update!(billing_treatment: "quoted_fixed")
    pennylane_invoices(:sl_one).update!(amount: 1500, currency: "EUR", invoice_date: Date.new(2026, 9, 1))
    clients(:acme).update!(active: false)

    get root_path(billing_month: "2026-09")
    assert_response :success
    assert_select ".billing-breakdown__item", text: /Quoted\/fixed/ do
      assert_select "strong", "1,500 €"
    end

    get billing_category_path("quoted_fixed", month: "2026-09")
    assert_response :success
    assert_select ".billing-detail-row__main strong", "SL-001"

    get billing_category_path("quoted_fixed", month: "2026-10")
    assert_response :success
    assert_select ".billing-detail-row", 0
  end

  test "archived quoted projects remain scoped to the current user" do
    project = projects(:other)
    project.update!(billing_treatment: "quoted_fixed", active: false)
    invoice = pennylane_invoices(:sl_one)
    invoice.update!(amount: 1500, currency: "EUR", invoice_date: Date.new(2026, 9, 1))
    ProjectPennylaneInvoice.create!(project:, pennylane_invoice: invoice)

    get billing_category_path("quoted_fixed", month: "2026-09")
    assert_response :success
    assert_select ".billing-detail-row", 0
    assert_select ".billing-detail-card__total strong", "-"
  end

  test "an invoice shared by active and archived quoted projects is counted once" do
    projects(:website).update!(billing_treatment: "quoted_fixed")
    invoice = pennylane_invoices(:sl_one)
    invoice.update!(amount: 1500, currency: "EUR", invoice_date: Date.new(2026, 9, 1))
    archived_project = Project.create!(
      name: "Archived fixed scope", client: clients(:acme), user: users(:roman),
      billing_treatment: "quoted_fixed", active: false
    )
    ProjectPennylaneInvoice.create!(project: archived_project, pennylane_invoice: invoice)

    get billing_category_path("quoted_fixed", month: "2026-09")
    assert_response :success
    assert_select ".billing-detail-row", 1
    assert_select ".billing-detail-row__project-link", 2
    assert_select ".billing-detail-card__total strong", "1,500.00 €"
  end

  test "redirects when billing reporting is disabled" do
    users(:roman).update!(billing_reports_enabled: false)

    get billing_path(month: "2026-09")

    assert_redirected_to root_path
    assert_equal "Billing reporting is disabled for your account", flash[:alert]
  end
end
