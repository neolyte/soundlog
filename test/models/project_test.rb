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

  test "make time entries billable updates only non-billable entries" do
    project = Project.create!(name: "Backfill", client: clients(:acme), user: users(:roman), billable: true, billing_treatment: "invoiceable")
    non_billable_entry = TimeEntry.create!(project:, user: users(:roman), date: Date.current, hours: 1, status: "non-billable")
    override_entry = TimeEntry.create!(project:, user: users(:roman), date: Date.current, hours: 1, status: "non-billable", billing_treatment: "quoted_fixed")
    billed_entry = TimeEntry.create!(project:, user: users(:roman), date: Date.current, hours: 1, status: "billed")

    assert_equal 2, project.non_billable_time_entries_count
    assert_equal 2, project.make_time_entries_billable!
    assert_equal "unbilled", non_billable_entry.reload.status
    assert_equal "unbilled", override_entry.reload.status
    assert_equal "quoted_fixed", override_entry.billing_treatment
    assert_equal "billed", billed_entry.reload.status
  end

  test "make time entries billable does nothing when project default is not billable" do
    project = Project.create!(name: "Free Backfill", client: clients(:acme), user: users(:roman), billable: false, billing_treatment: "invoiceable")
    entry = TimeEntry.create!(project:, user: users(:roman), date: Date.current, hours: 1, status: "non-billable")

    assert_equal 0, project.make_time_entries_billable!
    assert_equal "non-billable", entry.reload.status
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
