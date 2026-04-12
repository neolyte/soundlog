class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy]
  before_action :set_client, only: [:index, :new, :create]
  before_action :authorize_project_access, only: [:show, :edit, :update, :destroy]
  before_action :authorize_client_access, only: [:index, :new, :create]

  def index
    @projects =
      if @client
        project_scope.where(client: @client)
      else
        project_scope
      end
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
  end

  def edit; end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated successfully"
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
    scope.preload(:client, :user, :time_entries).ordered_by_recent_activity
  end

  def project_params
    params.require(:project).permit(:name, :description, :total_hours)
  end
end
