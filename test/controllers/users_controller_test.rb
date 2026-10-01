require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_path, params: { email: "admin@example.com", password: "password" }
  end

  test "updates user details without requiring a password change" do
    user = users(:roman)
    original_password_digest = user.password_digest

    patch user_path(user), params: {
      user: {
        first_name: "Updated",
        last_name: user.last_name,
        email: user.email,
        password: "",
        password_confirmation: "",
        admin: "0",
        pennylane_enabled: user.pennylane_enabled ? "1" : "0",
        billing_reports_enabled: user.billing_reports_enabled ? "1" : "0"
      }
    }

    assert_redirected_to users_path
    assert_equal "Updated", user.reload.first_name
    assert_equal original_password_digest, user.password_digest
    assert user.authenticate("password")
  end
end
