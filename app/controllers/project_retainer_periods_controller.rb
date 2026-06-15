class ProjectRetainerPeriodsController < ApplicationController
  before_action :set_project
  before_action :authorize_project_access

  def index
    @retainer_periods = @project.retainer_periods.recent_first.to_a
    @retainer_period = ProjectRetainerPeriod.new(project: @project, month: Date.current.beginning_of_month)
  end

  def create
    unless @project.monthly_retainer?
      redirect_to project_path(@project, project_navigation_redirect_params), alert: "Set a monthly retainer before adding monthly overrides"
      return
    end

    month = parse_month_param(retainer_period_params[:month])
    period = @project.retainer_periods.find_or_initialize_by(month:)
    period.assign_attributes(
      retainer_hours: retainer_period_params[:retainer_hours],
      note: retainer_period_params[:note]
    )

    if month.present? && period.save
      redirect_to project_retainer_periods_path(@project, project_navigation_redirect_params), notice: "Retainer override saved"
    else
      message = period.errors.full_messages.to_sentence.presence || "Choose a valid month"
      redirect_to project_retainer_periods_path(@project, project_navigation_redirect_params), alert: message
    end
  end

  def destroy
    @project.retainer_periods.find(params[:id]).destroy
    redirect_to project_retainer_periods_path(@project, project_navigation_redirect_params), notice: "Retainer override removed"
  end

  private

  def set_project
    @project = Project.includes(:client).find(params[:project_id])
  end

  def authorize_project_access
    unless admin? || @project.user_id == current_user.id || @project.client.user_id == current_user.id
      redirect_to root_path, alert: "You don't have permission to access this"
    end
  end

  def retainer_period_params
    params.require(:project_retainer_period).permit(:month, :retainer_hours, :note)
  end

  def parse_month_param(value)
    return if value.blank?

    Date.iso8601("#{value}-01").beginning_of_month
  rescue ArgumentError, Date::Error
    nil
  end

  def project_navigation_redirect_params
    params[:source] == "projects" ? { source: "projects" } : {}
  end
end
