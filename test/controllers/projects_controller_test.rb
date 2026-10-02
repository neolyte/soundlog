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

  test "creating a retainer project creates the current monthly included row" do
    post client_projects_path(clients(:acme)), params: {
      project: {
        name: "Monthly Support",
        billing_treatment: "retainer",
        monthly_retainer_hours: 20
      }
    }

    project = Project.order(:created_at).last

    assert_redirected_to project_path(project)
    assert_equal 1, project.retainer_periods.count
    assert_equal Date.current.beginning_of_month, project.retainer_periods.first.month
    assert_equal BigDecimal("20.0"), project.retainer_periods.first.retainer_hours
  end
end
