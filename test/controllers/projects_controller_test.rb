require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_path, params: { email: "roman@example.com", password: "password" }
  end

  test "makes existing project entries billable" do
    project = Project.create!(name: "Backfill", client: clients(:acme), user: users(:roman), billable: true, billing_treatment: "invoiceable")
    entry = TimeEntry.create!(project:, user: users(:roman), date: Date.current, hours: 1, status: "non-billable")

    patch make_time_entries_billable_project_path(project)

    assert_redirected_to project_path(project)
    assert_equal "unbilled", entry.reload.status
    assert_equal "1 time entry made billable", flash[:notice]
  end

  test "does not make entries billable when project default is not billable" do
    project = Project.create!(name: "Free Backfill", client: clients(:acme), user: users(:roman), billable: false, billing_treatment: "invoiceable")
    entry = TimeEntry.create!(project:, user: users(:roman), date: Date.current, hours: 1, status: "non-billable")

    patch make_time_entries_billable_project_path(project)

    assert_redirected_to project_path(project)
    assert_equal "non-billable", entry.reload.status
    assert_equal "Set this project to a billable default before updating existing entries", flash[:alert]
  end
end
