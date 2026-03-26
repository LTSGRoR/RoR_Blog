
class PostsController < ApplicationController
  before_action :set_post, only: %i[show update destroy verify unverify]
  before_action :authorize_edit!, only: %i[update]
  before_action :authorize_admin!, only: %i[verify unverify]


  def index
    if current_user&.admin?
      @posts = Post.all
    else
      @posts = Post.verified
    end
    render json: @posts
  end

  def show
  end

  def new
    @post = Post.new
  end

  def edit
  end


  def create
    @post = Post.new(post_params)
    @post.user = current_user if respond_to?(:current_user)
    @post.verified = false
    if @post.save
      redirect_to @post, notice: "Post was successfully created."
    else
      flash.now[:alert] = @post.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @post.update(post_params)
      render json: @post
    else
      render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def verify
    @post.verify!(current_user)
    render json: @post
  end

  def unverify
    @post.unverify!
    render json: @post
  end

  private

  def set_post
    @post = Post.find_by(id: params[:id])
    unless @post
      render json: { error: 'Post not found.' }, status: :not_found
    end
  end

  def post_params
    params.require(:post).permit(:title, :body, :status)
  end

  def authorize_edit!
    unless @post.editable_by?(current_user)
      render json: { error: 'You are not allowed to edit this post.' }, status: :forbidden
    end
  end

  def authorize_admin!
    unless current_user&.admin?
      render json: { error: 'Admin only.' }, status: :forbidden
    end
  end
end
