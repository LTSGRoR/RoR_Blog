class UsersController < ApplicationController
  def show
    @user = User.includes(:posts).find(params[:id])
    @posts = @user.posts.published.order(created_at: :desc)
  end
end
