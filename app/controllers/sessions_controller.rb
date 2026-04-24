class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
  end

  def create
    user = User.authenticate(params[:email], params[:password])

    if user
      session[:user_id] = user.id
      session[:admin_view_mode] = "personal" if user.admin?
      redirect_to root_path, notice: "Logged in successfully"
    else
      redirect_to login_path, alert: "Invalid email or password"
    end
  end

  def update_view_mode
    unless current_user&.admin?
      redirect_back fallback_location: root_path, alert: "You don't have permission to access this"
      return
    end

    session[:admin_view_mode] = params[:mode] == "all" ? "all" : "personal"
    redirect_back fallback_location: root_path, notice: "View mode updated"
  end

  def destroy
    session[:user_id] = nil
    session[:admin_view_mode] = nil
    redirect_to login_path, notice: "Logged out successfully"
  end
end
