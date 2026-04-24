class AccountsController < ApplicationController
  def edit
  end

  def update
    if current_password_invalid?
      flash.now[:alert] = "Current password is incorrect"
      render :edit, status: :unprocessable_entity
      return
    end

    if current_user.update(password_params)
      redirect_to edit_account_path, notice: "Password updated successfully"
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:account).permit(:password, :password_confirmation)
  end

  def current_password_invalid?
    !current_user.authenticate(params.dig(:account, :current_password).to_s)
  end
end
