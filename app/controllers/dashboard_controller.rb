class DashboardController < ApplicationController
  def index
    if current_user.admin?
      @total_clients = Client.count
      @total_projects = Project.active.count
      @total_time_entries = TimeEntry.count
      @time_entries_this_month = TimeEntry.for_month(Date.current).count

      chart_range = (Date.current - 6.days)..Date.current
      totals_by_day = TimeEntry.where(date: chart_range).group(:date).sum(:hours)
      @dashboard_chart_labels = chart_range.map { |date| date.strftime("%d %b") }
      @dashboard_chart_values = chart_range.map { |date| totals_by_day[date].to_f }
      @hours_last_7_days = @dashboard_chart_values.sum

      @recent_time_entries = TimeEntry.includes(:user, project: :client).ordered.limit(7).to_a
      @recent_projects = Project.active.preload(:client, :user, :time_entries).ordered_by_recent_activity.limit(7).to_a
    else
      redirect_to time_entries_path
    end
  end
end
