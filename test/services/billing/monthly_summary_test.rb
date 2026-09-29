require "test_helper"

module Billing
  class MonthlySummaryTest < ActiveSupport::TestCase
    test "separates retainer hours from other included maintenance" do
      month = Date.new(2026, 9, 1)
      retainer_project = Project.create!(
        name: "Retainer",
        client: clients(:acme),
        user: users(:roman),
        billing_treatment: "retainer",
        monthly_retainer_hours: 20,
        hourly_rate: 125,
        hourly_rate_currency: "EUR"
      )
      overage_retainer_project = Project.create!(
        name: "Overage Retainer",
        client: clients(:acme),
        user: users(:roman),
        billing_treatment: "retainer",
        monthly_retainer_hours: 5,
        hourly_rate: 100,
        hourly_rate_currency: "USD"
      )
      included_project = Project.create!(
        name: "Hosting",
        client: clients(:acme),
        user: users(:roman),
        billing_treatment: "included_maintenance"
      )
      quoted_project = Project.create!(
        name: "Fixed Scope",
        client: clients(:acme),
        user: users(:roman),
        billing_treatment: "quoted_fixed",
        total_hours: 12,
        sold_amount: 4000,
        sold_currency: "USD"
      )
      current_invoice = PennylaneInvoice.create!(
        remote_id: "inv_current",
        number: "SL-CURRENT",
        amount: 1500,
        currency: "USD",
        invoice_date: month
      )
      previous_invoice = PennylaneInvoice.create!(
        remote_id: "inv_previous",
        number: "SL-PREVIOUS",
        amount: 900,
        currency: "USD",
        invoice_date: month.prev_month
      )
      ProjectPennylaneInvoice.create!(project: quoted_project, pennylane_invoice: current_invoice)
      ProjectPennylaneInvoice.create!(project: quoted_project, pennylane_invoice: previous_invoice)
      retainer_entry = TimeEntry.create!(project: retainer_project, user: users(:roman), date: month, hours: 2, status: "unbilled")
      overage_retainer_entry = TimeEntry.create!(project: overage_retainer_project, user: users(:roman), date: month, hours: 6, status: "unbilled")
      included_entry = TimeEntry.create!(project: included_project, user: users(:roman), date: month, hours: 1.5, status: "unbilled")
      quoted_entry = TimeEntry.create!(project: quoted_project, user: users(:roman), date: month, hours: 3, status: "unbilled")

      summary = Billing::MonthlySummary.new(
        entries: TimeEntry.where(id: [retainer_entry.id, overage_retainer_entry.id, included_entry.id, quoted_entry.id]).includes(project: :retainer_periods).to_a,
        projects: Project.where(id: [retainer_project.id, overage_retainer_project.id, included_project.id, quoted_project.id]).includes(:retainer_periods, :pennylane_invoices).to_a,
        month:
      )

      assert_equal BigDecimal("8.0"), summary.retainer_hours
      assert_equal BigDecimal("25.0"), summary.retainer_budget_hours
      assert_equal BigDecimal("1.0"), summary.retainer_overage_hours
      assert_equal BigDecimal("2500.0"), summary.retainer_amounts_by_currency["EUR"]
      assert_equal BigDecimal("600.0"), summary.retainer_amounts_by_currency["USD"]
      assert_equal BigDecimal("1.5"), summary.non_retainer_included_maintenance_hours
      assert_equal BigDecimal("1.5"), summary.included_maintenance_hours
      assert_equal BigDecimal("3.0"), summary.quoted_fixed_hours
      assert_equal BigDecimal("4000.0"), summary.quoted_fixed_amounts_by_currency["USD"]
      assert_equal BigDecimal("1500.0"), summary.quoted_fixed_billed_amounts_by_currency["USD"]
    end
  end
end
