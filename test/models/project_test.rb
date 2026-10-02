require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "billing status is invoice linked when a Pennylane invoice is linked" do
    assert_equal "invoice_linked", projects(:website).billing_status
    assert_equal "Invoice linked", projects(:website).billing_status_label
  end

  test "billing status is not invoiced without linked Pennylane invoices" do
    project = Project.create!(name: "Unlinked", client: clients(:acme), user: users(:roman), billable: true)

    assert_equal "not_invoiced", project.billing_status
    assert_equal "No invoice linked", project.billing_status_label
  end

  test "sold amount and currency can be set together" do
    project = Project.new(name: "Fixed Price", client: clients(:acme), user: users(:roman), sold_amount: 5000, sold_currency: "USD")

    assert project.valid?
  end

  test "sold amount requires sold currency" do
    project = Project.new(name: "Fixed Price", client: clients(:acme), user: users(:roman), sold_amount: 5000)

    assert_not project.valid?
    assert_includes project.errors[:sold_currency], "must be selected when sold amount is set"
  end

  test "sold currency requires sold amount" do
    project = Project.new(name: "Fixed Price", client: clients(:acme), user: users(:roman), sold_currency: "EUR")

    assert_not project.valid?
    assert_includes project.errors[:sold_amount], "must be set when sold currency is selected"
  end

  test "sold currency is limited to eur and usd" do
    project = Project.new(name: "Fixed Price", client: clients(:acme), user: users(:roman), sold_amount: 5000, sold_currency: "GBP")

    assert_not project.valid?
    assert_includes project.errors[:sold_currency], "is not included in the list"
  end

  test "sold currency is normalized to uppercase" do
    project = Project.create!(name: "Fixed Price", client: clients(:acme), user: users(:roman), sold_amount: 5000, sold_currency: "usd")

    assert_equal "USD", project.sold_currency
  end

  test "hourly rate can be set for retainer projects" do
    project = Project.new(
      name: "Retainer",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "retainer",
      monthly_retainer_hours: 10,
      hourly_rate: 120,
      hourly_rate_currency: "EUR"
    )

    assert project.valid?
  end

  test "billing treatment defaults to invoiceable" do
    project = Project.new(name: "Default Billing", client: clients(:acme), user: users(:roman))

    assert project.valid?
    assert_equal "invoiceable", project.billing_treatment
    assert_equal "Invoiceable", project.billing_treatment_label
  end

  test "included treatment is labeled as included maintenance" do
    project = Project.new(name: "Retainer", client: clients(:acme), user: users(:roman), billing_treatment: "included_maintenance")

    assert_equal "Included maintenance", project.billing_treatment_label
  end

  test "retainer treatment is labeled as retainer" do
    project = Project.new(
      name: "Retainer",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "retainer",
      monthly_retainer_hours: 10
    )

    assert_equal "Retainer", project.billing_treatment_label
    assert project.retainer?
    assert project.monthly_retainer?
  end

  test "retainer treatment requires monthly included hours" do
    project = Project.new(name: "Retainer", client: clients(:acme), user: users(:roman), billing_treatment: "retainer")

    assert_not project.valid?
    assert_includes project.errors[:monthly_retainer_hours], "must be greater than 0 for retainer projects"
  end

  test "monthly included hours are read from monthly rows only" do
    month = Date.new(2026, 9, 1)
    project = Project.create!(
      name: "Retainer",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "retainer",
      monthly_retainer_hours: 20
    )

    assert_nil project.monthly_retainer_hours_for(month)

    project.retainer_periods.create!(month:, retainer_hours: 12)

    assert_equal BigDecimal("12.0"), project.monthly_retainer_hours_for(month)
  end

  test "seeding a retainer month does not update an existing monthly row" do
    month = Date.new(2026, 9, 1)
    project = Project.create!(
      name: "Retainer",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "retainer",
      monthly_retainer_hours: 20
    )

    project.ensure_retainer_period_for(month)
    project.update!(monthly_retainer_hours: 10)
    project.ensure_retainer_period_for(month)

    assert_equal 1, project.retainer_periods.where(month:).count
    assert_equal BigDecimal("20.0"), project.monthly_retainer_hours_for(month)
  end

  test "current retainer period seeding only runs for the current month" do
    project = Project.create!(
      name: "Retainer",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "retainer",
      monthly_retainer_hours: 20
    )

    Project.ensure_current_retainer_periods_for([project], Date.current.prev_month)

    assert_nil project.monthly_retainer_hours_for(Date.current.prev_month)

    Project.ensure_current_retainer_periods_for([project], Date.current)

    assert_equal BigDecimal("20.0"), project.monthly_retainer_hours_for(Date.current)
  end

  test "monthly included hours alone do not make a project a retainer" do
    project = Project.new(
      name: "Included Maintenance",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "included_maintenance",
      monthly_retainer_hours: 10
    )

    assert_not project.retainer?
    assert_not project.monthly_retainer?
  end

  test "billing treatment is limited to supported values" do
    project = Project.new(name: "Invalid Billing", client: clients(:acme), user: users(:roman), billing_treatment: "overage")

    assert_not project.valid?
    assert_includes project.errors[:billing_treatment], "is not included in the list"
  end

  test "time entries are billable by default when project is billable" do
    project = Project.new(name: "Hourly", client: clients(:acme), user: users(:roman), billable: true, billing_treatment: "invoiceable")

    assert project.time_entries_billable_by_default?
  end

  test "time entries are not billable by default when project is not billable" do
    project = Project.new(name: "Maintenance", client: clients(:acme), user: users(:roman), billable: false, billing_treatment: "included_maintenance")

    assert_not project.time_entries_billable_by_default?
  end

  test "no charge projects are not billable by default" do
    project = Project.new(name: "Free Help", client: clients(:acme), user: users(:roman), billable: true, billing_treatment: "not_charged")

    assert_not project.time_entries_billable_by_default?
  end

  test "hourly rate and currency can be set together" do
    project = Project.new(name: "Hourly", client: clients(:acme), user: users(:roman), hourly_rate: 120, hourly_rate_currency: "eur")

    assert project.valid?
    assert_equal "EUR", project.hourly_rate_currency
  end

  test "hourly rate requires currency" do
    project = Project.new(name: "Hourly", client: clients(:acme), user: users(:roman), hourly_rate: 120)

    assert_not project.valid?
    assert_includes project.errors[:hourly_rate_currency], "must be selected when hourly rate is set"
  end

  test "hourly rate currency requires hourly rate" do
    project = Project.new(name: "Hourly", client: clients(:acme), user: users(:roman), hourly_rate_currency: "EUR")

    assert_not project.valid?
    assert_includes project.errors[:hourly_rate], "must be set when hourly rate currency is selected"
  end
end
