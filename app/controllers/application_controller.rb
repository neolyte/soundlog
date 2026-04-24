class ApplicationController < ActionController::Base
  helper_method :current_user, :logged_in?, :admin?, :current_timer, :admin_view_all?, :admin_view_personal?
  before_action :require_login
  before_action :set_timer_context, if: :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def current_timer
    @current_timer
  end

  def admin?
    current_user&.admin?
  end

  def admin_view_all?
    admin? && session[:admin_view_mode] == "all"
  end

  def admin_view_personal?
    admin? && !admin_view_all?
  end

  def require_login
    redirect_to login_path, alert: "Please log in first" unless logged_in?
  end

  def require_admin
    redirect_to root_path, alert: "You don't have permission to access this" unless admin?
  end

  # Authorization check: user can only access their own resources, unless admin
  def authorize_user_resource(resource)
    unless admin? || resource.user_id == current_user.id
      redirect_to root_path, alert: "You don't have permission to access this"
    end
  end

  def set_timer_context
    @current_timer = current_user.timer
    @timer_projects = Project.for_user(current_user, admin_view_all?).active.includes(:client).order(:name)
  end
end
