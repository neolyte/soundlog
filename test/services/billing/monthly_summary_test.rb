require "test_helper"

module Billing
  class MonthlySummaryTest < ActiveSupport::TestCase
    test "separates retainer hours from other included maintenance" do
      month = Date.new(2026, 9, 1)
      retainer_project = Project.create!(
        name: "Retainer",
        client: clients(:acme),
        user: users(:roman),
        billing_treatment: "included_maintenance",
        monthly_retainer_hours: 20
      )
      included_project = Project.create!(
        name: "Hosting",
        client: clients(:acme),
        user: users(:roman),
        billing_treatment: "included_maintenance"
      )
      retainer_entry = TimeEntry.create!(project: retainer_project, user: users(:roman), date: month, hours: 2, status: "unbilled")
      included_entry = TimeEntry.create!(project: included_project, user: users(:roman), date: month, hours: 1.5, status: "unbilled")

      summary = Billing::MonthlySummary.new(
        entries: TimeEntry.where(id: [retainer_entry.id, included_entry.id]).includes(project: :retainer_periods).to_a,
        projects: [retainer_project, included_project],
        month:
      )

      assert_equal BigDecimal("2.0"), summary.retainer_hours
      assert_equal BigDecimal("20.0"), summary.retainer_budget_hours
      assert_equal BigDecimal("1.5"), summary.non_retainer_included_maintenance_hours
      assert_equal BigDecimal("3.5"), summary.included_maintenance_hours
    end
  end
end
