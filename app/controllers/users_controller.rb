class UsersController < ApplicationController
  before_action :require_admin
  before_action :set_user, only: [:edit, :update]

  def index
    @users = User.order(:last_name, :first_name, :email)
  end

  def new
    @user = User.new(admin: false)
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to users_path, notice: "User created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params_for_update)
      redirect_to users_path, notice: "User updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :admin)
  end

  def user_params_for_update
    permitted_params = user_params

    if permitted_params[:password].blank?
      permitted_params.except(:password, :password_confirmation)
    else
      permitted_params
    end
  end
end
