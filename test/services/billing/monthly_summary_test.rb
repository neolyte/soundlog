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
        billing_treatment: "included_maintenance",
        sold_amount: 80,
        sold_currency: "EUR"
      )
      included_project_without_usage = Project.create!(
        name: "Hosting Without Usage",
        client: clients(:acme),
        user: users(:roman),
        billing_treatment: "included_maintenance",
        sold_amount: 120,
        sold_currency: "EUR"
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
      retainer_project.retainer_periods.create!(month:, retainer_hours: 20)
      overage_retainer_project.retainer_periods.create!(month:, retainer_hours: 5)
      retainer_entry = TimeEntry.create!(project: retainer_project, user: users(:roman), date: month, hours: 2, status: "unbilled")
      overage_retainer_entry = TimeEntry.create!(project: overage_retainer_project, user: users(:roman), date: month, hours: 6, status: "unbilled")
      included_entry = TimeEntry.create!(project: included_project, user: users(:roman), date: month, hours: 1.5, status: "unbilled")
      quoted_entry = TimeEntry.create!(project: quoted_project, user: users(:roman), date: month, hours: 3, status: "unbilled")

      summary = Billing::MonthlySummary.new(
        entries: TimeEntry.where(id: [retainer_entry.id, overage_retainer_entry.id, included_entry.id, quoted_entry.id]).includes(project: :retainer_periods).to_a,
        projects: Project.where(id: [retainer_project.id, overage_retainer_project.id, included_project.id, included_project_without_usage.id, quoted_project.id]).includes(:retainer_periods, :pennylane_invoices).to_a,
        month:
      )

      assert_equal BigDecimal("8.0"), summary.retainer_hours
      assert_equal BigDecimal("25.0"), summary.retainer_budget_hours
      assert_equal BigDecimal("1.0"), summary.retainer_overage_hours
      assert_equal BigDecimal("2500.0"), summary.retainer_amounts_by_currency["EUR"]
      assert_equal BigDecimal("600.0"), summary.retainer_amounts_by_currency["USD"]
      assert_equal BigDecimal("1.5"), summary.non_retainer_included_maintenance_hours
      assert_equal BigDecimal("1.5"), summary.included_maintenance_hours
      assert_equal BigDecimal("200.0"), summary.included_maintenance_amounts_by_currency["EUR"]
      assert_equal BigDecimal("3.0"), summary.quoted_fixed_hours
      assert_equal BigDecimal("4000.0"), summary.quoted_fixed_amounts_by_currency["USD"]
      assert_equal BigDecimal("1500.0"), summary.quoted_fixed_billed_amounts_by_currency["USD"]
      assert_equal BigDecimal("2700.0"), summary.revenue_amounts_by_currency["EUR"]
      assert_equal BigDecimal("2100.0"), summary.revenue_amounts_by_currency["USD"]

      retainer_rows = summary.breakdown_rows("retainer")
      retainer_row = retainer_rows.find { |row| row.label == "Retainer" }
      overage_row = retainer_rows.find { |row| row.label == "Overage Retainer" }

      assert_equal BigDecimal("2.0"), retainer_row.hours
      assert_equal BigDecimal("20.0"), retainer_row.billable_hours
      assert_equal BigDecimal("2500.0"), retainer_row.amount
      assert_equal "Monthly minimum", retainer_row.note
      assert_equal BigDecimal("6.0"), overage_row.hours
      assert_equal BigDecimal("5.0"), overage_row.included_hours
      assert_equal BigDecimal("1.0"), overage_row.overage_hours
      assert_equal BigDecimal("600.0"), overage_row.amount
      assert_equal "Over included hours", overage_row.note

      maintenance_rows = summary.breakdown_rows("included_maintenance")
      assert_equal BigDecimal("80.0"), maintenance_rows.find { |row| row.label == "Hosting" }.amount
      assert_equal BigDecimal("120.0"), maintenance_rows.find { |row| row.label == "Hosting Without Usage" }.amount

      quoted_rows = summary.breakdown_rows("quoted_fixed")
      assert_equal ["SL-CURRENT"], quoted_rows.map(&:label)
      assert_equal BigDecimal("1500.0"), quoted_rows.first.amount
      assert_equal [quoted_project], quoted_rows.first.projects
    end

    test "retainer project default does not count without a monthly row" do
      month = Date.new(2026, 9, 1)
      project = Project.create!(
        name: "Retainer Without Row",
        client: clients(:acme),
        user: users(:roman),
        billing_treatment: "retainer",
        monthly_retainer_hours: 20,
        hourly_rate: 125,
        hourly_rate_currency: "EUR"
      )
      entry = TimeEntry.create!(project:, user: users(:roman), date: month, hours: 2, status: "unbilled")

      summary = Billing::MonthlySummary.new(
        entries: TimeEntry.where(id: entry.id).includes(project: :retainer_periods).to_a,
        projects: Project.where(id: project.id).includes(:retainer_periods, :pennylane_invoices).to_a,
        month:
      )

      assert_equal BigDecimal("0"), summary.retainer_hours
      assert_equal BigDecimal("0"), summary.retainer_budget_hours
      assert_empty summary.retainer_amounts_by_currency
      assert_empty summary.breakdown_rows("retainer")
    end

    test "invoiceable totals include billed and unbilled entries" do
      month = Date.new(2026, 9, 1)
      project = Project.create!(
        name: "Hourly",
        client: clients(:acme),
        user: users(:roman),
        billing_treatment: "invoiceable",
        hourly_rate: 100,
        hourly_rate_currency: "EUR"
      )
      unbilled_entry = TimeEntry.create!(project:, user: users(:roman), date: month, hours: 1.5, status: "unbilled")
      billed_entry = TimeEntry.create!(project:, user: users(:roman), date: month, hours: 2, status: "billed")
      non_billable_entry = TimeEntry.create!(project:, user: users(:roman), date: month, hours: 3, status: "non-billable")

      summary = Billing::MonthlySummary.new(
        entries: TimeEntry.where(id: [unbilled_entry.id, billed_entry.id, non_billable_entry.id]).includes(project: :retainer_periods).to_a,
        projects: [project],
        month:
      )

      assert_equal BigDecimal("3.5"), summary.invoiceable_hours
      assert_equal BigDecimal("350.0"), summary.invoiceable_amounts_by_currency["EUR"]
      assert_equal BigDecimal("1.5"), summary.invoiceable_open_hours
      assert_equal BigDecimal("150.0"), summary.invoiceable_open_amounts_by_currency["EUR"]
      assert_equal BigDecimal("350.0"), summary.revenue_amounts_by_currency["EUR"]

      invoiceable_row = summary.breakdown_rows("invoiceable").first
      assert_equal "Hourly", invoiceable_row.label
      assert_equal BigDecimal("3.5"), invoiceable_row.hours
      assert_equal BigDecimal("3.5"), invoiceable_row.billable_hours
      assert_equal BigDecimal("100.0"), invoiceable_row.rate
      assert_equal BigDecimal("350.0"), invoiceable_row.amount
      assert_equal 2, invoiceable_row.entries_count
    end
  end
end
