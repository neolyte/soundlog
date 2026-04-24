class DashboardController < ApplicationController
  def index
    client_scope = Client.for_user(current_user, admin_view_all?).active
    project_scope = Project.for_user(current_user, admin_view_all?).active
    time_entry_scope = TimeEntry.for_user(current_user, admin_view_all?)

    @total_clients = client_scope.count
    @total_projects = project_scope.count
    @total_time_entries = time_entry_scope.count
    @time_entries_this_month = time_entry_scope.for_month(Date.current).count

    chart_range = (Date.current - 6.days)..Date.current
    totals_by_day = time_entry_scope.where(date: chart_range).group(:date).sum(:hours)
    @dashboard_chart_labels = chart_range.map { |date| date.strftime("%d %b") }
    @dashboard_chart_values = chart_range.map { |date| totals_by_day[date].to_f }
    @hours_last_7_days = @dashboard_chart_values.sum

    @recent_time_entries = time_entry_scope.includes(:user, project: :client).ordered.limit(7).to_a
    @recent_projects = project_scope.preload(:client, :user, :time_entries).ordered_by_recent_activity.limit(7).to_a
  end
end
