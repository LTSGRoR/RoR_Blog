class PostsController < ApplicationController
  before_action :set_post, only: %i[show update destroy]

  def index
    @posts = Post.all
    render json: @posts
  end

  def show
    render json: @post
  end

  def create
    @post = Post.new(post_params)
    @post.user = current_user if respond_to?(:current_user)
    if @post.save
      render json: @post, status: :created
    else
      render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :body, :status, :user_id)
  end
end
