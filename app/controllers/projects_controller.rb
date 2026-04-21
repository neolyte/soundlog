class ProjectsController < ApplicationController
  helper_method :projects_index_params

  before_action :set_project, only: [:show, :edit, :update, :destroy]
  before_action :set_client, only: [:index, :new, :create]
  before_action :authorize_project_access, only: [:show, :edit, :update, :destroy]
  before_action :authorize_client_access, only: [:index, :new, :create]

  def index
    @filter_query = params[:query].to_s.strip
    @archived_filter = archived_filter_param
    @sort_option = sort_option_param

    @projects = filtered_project_scope.preload(:client, :user, time_entries: :user).to_a
    @projects_count = @projects.count
    @logged_total = @projects.sum(&:total_hours_logged)
    @budget_total = @projects.filter_map(&:total_hours).sum
    @remaining_total = @projects.filter_map(&:remaining_hours).sum
  end

  def new
    @project = @client.projects.build
  end

  def create
    @project = current_user.projects.build(project_params.merge(client: @client))

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
    @project = Project.includes(:client, :user, :time_entries).find(params[:id])
  end

  def authorize_project_access
    authorize_user_resource(@project)
  end

  def authorize_client_access
    authorize_user_resource(@client) if @client
  end

  def project_scope
    scope = current_user.admin? ? Project.all : current_user.projects
    scope = scope.where(client: @client) if @client
    scope
  end

  def prepare_show_state
    @time_entries = @project.time_entries.ordered.includes(:user).to_a
    @page_total = @time_entries.sum(&:hours)
    @time_entry = TimeEntry.new(project: @project, date: Date.current)
    @show_log_time_form = params[:show_log_time] == "1"
  end

  def filtered_project_scope
    scope = project_scope

    scope =
      case @archived_filter
      when "archived"
        scope.archived
      when "all"
        scope
      else
        scope.active
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
      scope.ordered_by_recent_activity
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

  def projects_index_params(overrides = {})
    {
      query: @filter_query.presence,
      archived: (@archived_filter unless @archived_filter == "active"),
      sort: (@sort_option unless @sort_option == "recent")
    }.merge(overrides).compact
  end

  def project_params
    params.require(:project).permit(:name, :description, :total_hours, :active)
  end

  def project_navigation_redirect_params
    params[:source] == "projects" ? { source: "projects" } : {}
  end
end
