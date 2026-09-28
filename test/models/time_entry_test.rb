require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  test "effective billing treatment inherits from project" do
    project = Project.create!(
      name: "Maintenance",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "included_maintenance"
    )
    entry = TimeEntry.new(project:, user: users(:roman), date: Date.current, hours: 1, status: "unbilled")

    assert_equal "included_maintenance", entry.effective_billing_treatment
    assert entry.included_maintenance?
  end

  test "entry billing treatment overrides project default" do
    project = Project.create!(
      name: "Globalty Dev",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "invoiceable"
    )
    entry = TimeEntry.new(
      project:,
      user: users(:roman),
      date: Date.current,
      hours: 1,
      status: "unbilled",
      billing_treatment: "not_charged"
    )

    assert_equal "not_charged", entry.effective_billing_treatment
    assert entry.not_charged?
  end

  test "non-billable entries are treated as no charge" do
    project = Project.create!(
      name: "Hourly",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "invoiceable"
    )
    entry = TimeEntry.new(
      project:,
      user: users(:roman),
      date: Date.current,
      hours: 1,
      status: "non-billable",
      billing_treatment: "invoiceable"
    )

    assert_equal "not_charged", entry.effective_billing_treatment
  end

  test "invoiceable amount uses project hourly rate" do
    project = Project.create!(
      name: "Hourly",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "invoiceable",
      hourly_rate: 120,
      hourly_rate_currency: "EUR"
    )
    entry = TimeEntry.new(project:, user: users(:roman), date: Date.current, hours: 1.5, status: "unbilled")

    assert_equal BigDecimal("180.0"), entry.invoiceable_amount
  end

  test "billing category scope separates retainers from other included maintenance" do
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
    included_entry = TimeEntry.create!(project: included_project, user: users(:roman), date: month, hours: 1, status: "unbilled")

    scoped_entries = TimeEntry.where(id: [retainer_entry.id, included_entry.id])

    assert_equal [retainer_entry.id], scoped_entries.for_billing_category("retainer").pluck(:id)
    assert_equal [included_entry.id], scoped_entries.for_billing_category("included_maintenance").pluck(:id)
  end

  test "billing category scope treats non billable entries as no charge" do
    project = Project.create!(
      name: "Hourly",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "invoiceable"
    )
    no_charge_entry = TimeEntry.create!(project:, user: users(:roman), date: Date.current, hours: 1, status: "non-billable")
    invoiceable_entry = TimeEntry.create!(project:, user: users(:roman), date: Date.current, hours: 1, status: "unbilled")

    scoped_entries = TimeEntry.where(id: [no_charge_entry.id, invoiceable_entry.id])

    assert_equal [no_charge_entry.id], scoped_entries.for_billing_category("not_charged").pluck(:id)
    assert_equal [invoiceable_entry.id], scoped_entries.for_billing_category("invoiceable").pluck(:id)
  end
end
