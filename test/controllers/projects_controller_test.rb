require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_path, params: { email: "roman@example.com", password: "password" }
  end

  test "show renders one billing summary tile for the project treatment" do
    project = Project.create!(
      name: "Maintenance",
      client: clients(:acme),
      user: users(:roman),
      billing_treatment: "included_maintenance",
      sold_amount: 80,
      sold_currency: "EUR"
    )
    TimeEntry.create!(project:, user: users(:roman), date: Date.current, hours: 1.5, status: "unbilled")

    get project_path(project)

    assert_response :success
    assert_select ".billing-breakdown--single .billing-breakdown__item", 1
    assert_select ".billing-breakdown--single .billing-breakdown__item span", "Included maintenance"
    assert_no_match "Invoiceable open", response.body
    assert_no_match "Make existing entries billable", response.body
  end
end
