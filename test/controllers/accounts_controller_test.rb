require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_path, params: { email: "roman@example.com", password: "password" }
  end

  test "updates billing reporting preference without changing password" do
    patch account_path, params: { account: { billing_reports_enabled: "0" } }

    assert_redirected_to edit_account_path
    assert_not users(:roman).reload.billing_reports_enabled?
  end
end
