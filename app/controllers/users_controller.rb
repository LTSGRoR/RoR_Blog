class UsersController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      session[:user_id] = @user.id
      render json: { message: "Account created", user: { id: @user.id, email: @user.email, name: @user.name } }, status: :created
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def show
    @user = User.find(params[:id])
    render json: { id: @user.id, name: @user.name, email: @user.email }
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :avatar)
  end
end
