class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:email]&.downcase)
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      render json: { message: "Logged in", user: { id: user.id, email: user.email, name: user.name } }
    else
      render json: { error: "Invalid credentials" }, status: :unauthorized
    end
  end

  def destroy
    session.delete(:user_id)
    render json: { message: "Logged out" }
  end
end
