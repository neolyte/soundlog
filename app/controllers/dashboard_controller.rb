class DashboardController < ApplicationController
  def index
    if current_user.admin?
      @total_users = User.count
      @total_clients = Client.count
      @total_projects = Project.count
      @total_time_entries = TimeEntry.count
      @time_entries_this_month = TimeEntry.for_month(Date.current).count
      @projects = Project.preload(:client, :user, :time_entries).ordered_by_recent_activity.limit(12)
    else
      redirect_to time_entries_path
    end
  end
end
