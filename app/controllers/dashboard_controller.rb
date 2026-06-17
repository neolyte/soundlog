class DashboardController < ApplicationController
  def index
    client_scope = Client.for_user(current_user, admin_view_all?).active
    project_scope = Project.for_user(current_user, admin_view_all?).active
    time_entry_scope = TimeEntry.for_user(current_user, admin_view_all?)

    @total_clients = client_scope.count
    @total_projects = project_scope.count
    @total_time_entries = time_entry_scope.count
    @time_entries_this_month = time_entry_scope.for_month(Date.current).count

    @dashboard_chart_start_date = selected_chart_start_date
    @dashboard_chart_end_date = selected_chart_end_date
    @dashboard_hide_weekends = hide_weekends?
    @dashboard_chart_range_label = chart_range_label(@dashboard_chart_start_date, @dashboard_chart_end_date)

    chart_range = @dashboard_chart_start_date..@dashboard_chart_end_date
    chart_dates = chart_range.to_a
    chart_dates = chart_dates.reject { |date| date.saturday? || date.sunday? } if @dashboard_hide_weekends
    totals_by_day = time_entry_scope.where(date: chart_range).group(:date).sum(:hours)
    totals_by_project_day = time_entry_scope.where(date: chart_range).group(:project_id, :date).sum(:hours)
    totals_by_project_day = totals_by_project_day.select { |(_project_id, date), _hours| chart_dates.include?(date) }
    project_ids = totals_by_project_day
      .each_with_object(Hash.new(0)) { |((project_id, _date), hours), totals| totals[project_id] += hours }
      .sort_by { |_project_id, hours| -hours }
      .map(&:first)
    projects_by_id = Project.includes(:client).where(id: project_ids).index_by(&:id)

    @dashboard_chart_labels = chart_dates.map { |date| date.strftime("%d %b") }
    @dashboard_chart_values = chart_dates.map { |date| totals_by_day[date].to_f }
    @dashboard_chart_projects = project_ids.filter_map do |project_id|
      project = projects_by_id[project_id]
      next unless project

      {
        label: project.name,
        color: helpers.project_accent_colors(project)[:strong],
        values: chart_dates.map { |date| totals_by_project_day[[project_id, date]].to_f }
      }
    end
    @hours_in_chart_range = @dashboard_chart_values.sum

    @recent_time_entries = time_entry_scope.includes(:user, project: :client).ordered.limit(7).to_a
    @recent_projects = project_scope.preload(:client, :user, :time_entries).ordered_by_recent_activity.limit(7).to_a
  end

  private

  def selected_chart_start_date
    parse_date_param(params[:start_date]) || Date.current - 6.days
  end

  def selected_chart_end_date
    candidate = parse_date_param(params[:end_date]) || Date.current
    [candidate, selected_chart_start_date].max
  end

  def parse_date_param(value)
    return if value.blank?

    Date.iso8601(value)
  rescue ArgumentError, Date::Error
    nil
  end

  def hide_weekends?
    params[:hide_weekends] == "1"
  end

  def chart_range_label(start_date, end_date)
    return start_date.strftime("%d %b %Y") if start_date == end_date

    "#{start_date.strftime('%d %b %Y')} to #{end_date.strftime('%d %b %Y')}"
  end
end
