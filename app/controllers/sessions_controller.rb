class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
  end

  def create
    user = User.authenticate(params[:email], params[:password])

    if user
      session[:user_id] = user.id
      redirect_to root_path, notice: "Logged in successfully"
    else
      redirect_to login_path, alert: "Invalid email or password"
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to login_path, notice: "Logged out successfully"
  end
end
