class ProjectsController < ApplicationController
  PER_PAGE = 40
  helper_method :projects_index_params, :project_time_entries_params

  before_action :set_project, only: [:show, :edit, :update, :destroy]
  before_action :set_client, only: [:index, :new, :create]
  before_action :set_available_clients, only: [:new, :create]
  before_action :ensure_active_client_for_project_creation, only: [:new, :create]
  before_action :authorize_project_access, only: [:show, :edit, :update, :destroy]
  before_action :authorize_client_access, only: [:index, :new, :create]

  def index
    @filter_query = params[:query].to_s.strip
    @archived_filter = archived_filter_param
    @sort_option = sort_option_param
    @period_option = period_option_param
    @period_month = period_month_param
    @period_date_range = @period_month.all_month unless @period_option == "all_time"
    @retainer_progress_month = @period_option == "all_time" ? Date.current : @period_month
    @period_label = @period_option == "all_time" ? "All time" : @period_month.strftime("%B %Y")
    @retainer_period_label = @period_option == "all_time" ? "This month" : @period_label

    @projects = filtered_project_scope.preload(:client, :user, :retainer_periods, time_entries: :user).to_a
    @projects_count = @projects.count
    @logged_total = @projects.sum { |project| project_logged_total(project) }
    @budget_total = @projects.filter_map(&:total_hours).sum
    @remaining_total = @projects.filter_map(&:remaining_hours).sum
    @monthly_retainer_budget_total = @projects.filter_map { |project| project.monthly_retainer_hours_for(@retainer_progress_month) }.sum
    @monthly_retainer_remaining_total = @projects.filter_map { |project| project.monthly_retainer_remaining_hours(@retainer_progress_month) }.sum
  end

  def new
    @project = Project.new(client: @client)
  end

  def create
    selected_client = selected_client_for_project
    @project = Project.new(project_create_params.except(:client_id).merge(client: selected_client, user: selected_client&.user))

    if @project.save
      redirect_to @project, notice: "Project created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    prepare_show_state
  end

  def edit; end

  def update
    if @project.update(project_params)
      redirect_to project_path(@project, project_navigation_redirect_params), notice: "Project updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    client = @project.client
    @project.destroy
    redirect_to client_path(client), notice: "Project deleted successfully"
  end

  private

  def set_client
    @client = Client.find(params[:client_id]) if params[:client_id].present?
  end

  def set_project
    @project = Project.includes(:client, :user).find(params[:id])
  end

  def authorize_project_access
    unless admin? || @project.user_id == current_user.id || @project.client.user_id == current_user.id
      redirect_to root_path, alert: "You don't have permission to access this"
    end
  end

  def authorize_client_access
    authorize_user_resource(@client) if @client
  end

  def set_available_clients
    @available_clients = Client.for_user(current_user, admin_view_all?).active.order(:name).to_a
  end

  def ensure_active_client_for_project_creation
    return unless @client&.archived?

    redirect_to client_path(@client), alert: "Archived clients cannot have new projects"
  end

  def project_scope
    scope = Project.for_user(current_user, admin_view_all?)
    scope = scope.where(client: @client) if @client
    scope
  end

  def prepare_show_state
    @filter_start_date = selected_start_date
    @filter_end_date = selected_end_date
    @filter_query = params[:query].to_s.strip
    @filter_status = selected_time_entry_status
    @status_filter_options = TimeEntriesController::STATUS_FILTERS
    @date_filter_active = @filter_start_date.present? || @filter_end_date.present?
    @current_retainer_period = @project.retainer_period_for(Date.current)

    base_query = filtered_project_time_entries_scope
    @grand_total = base_query.sum(:hours)
    @total_entries = base_query.count
    @total_pages = [(@total_entries.to_f / PER_PAGE).ceil, 1].max
    @page = [[current_page_number, 1].max, @total_pages].min

    entries_query = base_query.ordered.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @time_entries = entries_query.includes(:user).to_a
    @page_total = @time_entries.sum(&:hours)
    @time_entry = TimeEntry.new(project: @project, date: Date.current)
    @show_log_time_form = params[:show_log_time] == "1"
  end

  def filtered_project_time_entries_scope
    scope = @project.time_entries
    scope = scope.where("time_entries.date >= ?", @filter_start_date) if @filter_start_date.present?
    scope = scope.where("time_entries.date <= ?", @filter_end_date) if @filter_end_date.present?
    scope = scope.where(status: @filter_status) if @filter_status.present?

    if @filter_query.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@filter_query)}%"
      scope = scope.joins(:user).where(
        "time_entries.description LIKE :pattern OR users.first_name LIKE :pattern OR users.last_name LIKE :pattern",
        pattern:
      )
    end

    scope
  end

  def filtered_project_scope
    scope = project_scope

    scope =
      if @client.present?
        case @archived_filter
        when "archived"
          scope.where(active: false)
        when "all"
          scope
        else
          scope.where(active: true)
        end
      else
        case @archived_filter
        when "archived"
          scope.archived
        when "all"
          scope
        else
          scope.active
        end
      end

    if @filter_query.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@filter_query)}%"
      scope = scope.joins(:client, :user).where(
        "projects.name LIKE :pattern OR clients.name LIKE :pattern OR projects.description LIKE :pattern OR users.first_name LIKE :pattern OR users.last_name LIKE :pattern",
        pattern:
      )
    end

    case @sort_option
    when "name"
      scope.order(Arel.sql("LOWER(projects.name) ASC"))
    when "hours_logged"
      scope
        .left_joins(:time_entries)
        .group("projects.id")
        .order(Arel.sql("COALESCE(SUM(time_entries.hours), 0) DESC"), Arel.sql("LOWER(projects.name) ASC"))
    else
      scope.ordered_by_retainer_first_recent_activity
    end
  end

  def archived_filter_param
    return "all" if params[:archived] == "all"
    return "archived" if params[:archived] == "archived"

    "active"
  end

  def sort_option_param
    return "name" if params[:sort] == "name"
    return "hours_logged" if params[:sort] == "hours_logged"

    "recent"
  end

  def period_option_param
    return "current_month" if params[:period] == "current_month"
    return "previous_month" if params[:period] == "previous_month"
    return "month" if params[:period] == "month"

    "all_time"
  end

  def period_month_param
    case @period_option
    when "current_month"
      Date.current
    when "previous_month"
      Date.current.prev_month
    when "month"
      parse_month_param(params[:month]) || Date.current
    else
      Date.current
    end
  end

  def parse_month_param(value)
    return if value.blank?

    Date.iso8601("#{value}-01")
  rescue ArgumentError, Date::Error
    nil
  end

  def projects_index_params(overrides = {})
    {
      query: @filter_query.presence,
      archived: (@archived_filter unless @archived_filter == "active"),
      sort: (@sort_option unless @sort_option == "recent"),
      period: (@period_option unless @period_option == "all_time"),
      month: (@period_month.strftime("%Y-%m") if @period_option == "month")
    }.merge(overrides).compact
  end

  def project_params
    params.require(:project).permit(:name, :description, :total_hours, :monthly_retainer_hours, :color, :billable, :active)
  end

  def project_create_params
    params.require(:project).permit(:name, :description, :total_hours, :monthly_retainer_hours, :color, :billable, :active, :client_id)
  end

  def project_logged_total(project)
    return project.total_hours_logged if @period_option == "all_time"

    project.total_hours_logged_between(@period_date_range)
  end

  def selected_client_for_project
    selected_client_id = project_create_params[:client_id].presence || @client&.id
    Client.for_user(current_user, admin_view_all?).active.find_by(id: selected_client_id)
  end

  def project_navigation_redirect_params
    params[:source] == "projects" ? { source: "projects" } : {}
  end

  def project_time_entries_params(overrides = {})
    {
      source: params[:source].presence,
      start_date: @filter_start_date&.to_s,
      end_date: @filter_end_date&.to_s,
      query: @filter_query.presence,
      status: @filter_status.presence,
      page: (@page if defined?(@page) && @page > 1)
    }.merge(overrides).compact
  end

  def selected_time_entry_status
    value = params[:status].to_s
    return value if TimeEntriesController::STATUS_FILTERS.key?(value)

    nil
  end

  def selected_start_date
    parse_date_param(params[:start_date])
  end

  def selected_end_date
    candidate = parse_date_param(params[:end_date])
    return candidate if selected_start_date.blank? || candidate.blank?

    [candidate, selected_start_date].max
  end

  def parse_date_param(value)
    return if value.blank?

    Date.iso8601(value)
  rescue ArgumentError, Date::Error
    nil
  end

  def current_page_number
    positive_integer(params[:page]) || 1
  end

  def positive_integer(value)
    parsed = Integer(value, 10)
    parsed.positive? ? parsed : nil
  rescue ArgumentError, TypeError
    nil
  end
end
