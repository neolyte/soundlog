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

  test "sold amount is not available for retainer projects yet" do
    project = Project.new(name: "Retainer", client: clients(:acme), user: users(:roman), monthly_retainer_hours: 10, sold_amount: 5000, sold_currency: "EUR")

    assert_not project.valid?
    assert_includes project.errors[:sold_amount], "is only available for non-retainer projects"
  end
end
