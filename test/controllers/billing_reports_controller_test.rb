require "test_helper"

class BillingReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_path, params: { email: "roman@example.com", password: "password" }
  end

  test "shows the selected billing month" do
    get billing_path(month: "2026-09")

    assert_response :success
    assert_select "h1", "Billing Report"
    assert_select ".projects-period-nav__label", "September 2026"
  end
end
