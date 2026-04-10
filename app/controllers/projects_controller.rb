class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy]
  before_action :authorize_project_access, only: [:show, :edit, :update, :destroy]

  def index
    @projects = current_user.admin? ? Project.all : current_user.projects
  end

  def new
    @project = Project.new
    @clients = current_user.admin? ? Client.all : current_user.clients
  end

  def create
    @project = current_user.projects.build(project_params)

    if @project.save
      redirect_to @project, notice: "Project created successfully"
    else
      @clients = current_user.admin? ? Client.all : current_user.clients
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
    @clients = current_user.admin? ? Client.all : current_user.clients
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated successfully"
    else
      @clients = current_user.admin? ? Client.all : current_user.clients
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_url, notice: "Project deleted successfully"
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def authorize_project_access
    authorize_user_resource(@project)
  end

  def project_params
    params.require(:project).permit(:name, :description, :client_id, :active)
  end
end
