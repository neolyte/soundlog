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
end
