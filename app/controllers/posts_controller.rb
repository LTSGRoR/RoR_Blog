
class PostsController < ApplicationController
  before_action :set_post, only: %i[show edit destroy verify unverify]
  before_action :authorize_admin!, only: %i[verify unverify]

  def index
    if params[:q].present?
      query = params[:q].to_s.strip
      if defined?(Searchkick)
        begin
          search_scope = current_user&.admin? ? {} : { verified: true }
          @posts = Post.search(
            query,
            fields: ["title^5", "tags^3", "body"],
            where: search_scope,
            page: @page,
            per_page: @per_page,
            operator: query.include?(' ') ? 'and' : 'or',
            misspellings: { below: 5 }
          )
        rescue StandardError => e
          Rails.logger.warn("Searchkick unavailable: #{e.class} - #{e.message}")
        end
      else
        scope = current_user&.admin? ? Post.all : Post.verified
        @posts = scope.where("title ILIKE :q", q: "%#{query}%").order(created_at: :desc).page(params[:page]).per(10)
      end
    else
      if current_user&.admin?
        @posts = Post.all.order(created_at: :desc).page(params[:page]).per(10)
      else
        @posts = Post.verified.page(params[:page]).per(10)
      end
    end
    respond_to do |format|
      format.html
      format.json do
        posts_json = @posts.map do |post|
          {
            id: post.id,
            title: post.title,
            body: post.body.to_plain_text,
            tags: post.tags.map(&:name),
            verified: post.verified,
            user: post.user&.name,
            created_at: post.created_at
          }
        end

        render json: {
          count: (@posts.respond_to?(:total_count) ? @posts.total_count : @posts.size),
          posts: posts_json
        }
      end
    end
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

  def destroy
    @post.destroy
    redirect_to posts_url, notice: 'Post was successfully destroyed.'
  end

  def verify
    @post.verify!(current_user)
    redirect_back fallback_location: posts_path, notice: 'Post has been verified.'
  end

  def unverify
    @post.unverify!
    redirect_back fallback_location: posts_path, notice: 'Post has been unverified.'
  end

  private

  def set_post
    @post = Post.find_by(id: params[:id])
    unless @post
      redirect_to posts_path, alert: 'Post not found.'
    end
  end

  def post_params
    params.require(:post).permit(:title, :body, :status, :tag_list, tag_ids: [])
  end

  def authorize_edit!
    unless @post.editable_by?(current_user)
      redirect_to @post, alert: 'You are not allowed to edit this post.'
    end
  end

  def authorize_admin!
    unless current_user&.admin?
      redirect_to posts_path, alert: 'Admin only.'
    end
  end

  def authorize_edit!
    unless @post.editable_by?(current_user)
      redirect_to @post, alert: 'You are not allowed to edit this post.'
    end
  end

  def authorize_admin!
    unless current_user&.admin?
      redirect_to posts_path, alert: 'Admin only.'
    end
  end
end
