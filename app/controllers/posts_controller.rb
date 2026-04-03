
class PostsController < ApplicationController
  before_action :set_post, only: %i[show edit update destroy verify unverify]
  before_action :authenticate_user!, only: %i[new create edit update destroy]
  before_action :authorize_post!, only: %i[edit update destroy]
  before_action :authorize_admin!, only: %i[verify unverify]

  def index
    @page     = params[:page] || 1
    @per_page = 10

    base_scope = if current_user&.admin?
      Post.where(status: Post.statuses[:published])
          .or(Post.where(user_id: current_user.id))
    elsif current_user
      Post.where(status: Post.statuses[:published], verified: true)
          .or(Post.where(user_id: current_user.id))
    else
      Post.where(status: Post.statuses[:published], verified: true)
    end

    if params[:q].present?
      query = params[:q].to_s.strip
      if defined?(Searchkick)
        begin
          search_scope = if current_user&.admin?
            {
              _or: [
                { status: Post.statuses[:published] },
                { user_id: current_user.id }
              ]
            }
          elsif current_user
            {
              _or: [
                { status: Post.statuses[:published], verified: true },
                { user_id: current_user.id }
              ]
            }
          else
            { status: Post.statuses[:published], verified: true }
          end
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
      end
      unless @posts
        @posts = base_scope.includes(:tags)
                          .left_joins(:tags)
                          .where("posts.title ILIKE :q OR tags.name ILIKE :q", q: "%#{query}%")
                          .distinct
                          .order(created_at: :desc)
                          .page(@page).per(@per_page)
      end
    else
      @posts = base_scope.includes(:tags).order(created_at: :desc).page(@page).per(@per_page)
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
    authorize @post
  end

  def edit
  end

  def update
    if @post.update(post_params)
      redirect_to @post, notice: "Post was successfully updated."
    else
      flash.now[:alert] = @post.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def create
    @post = Post.new(post_params)
    @post.user = current_user
    @post.verified = false
    authorize @post
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
    unless @post.published?
      redirect_back fallback_location: posts_path, alert: 'Only published posts can be verified.'
      return
    end
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
    permitted = params.require(:post).permit(:title, :body, :status, :tag_list, tag_ids: [])

    selected_tag_ids = Array(permitted[:tag_ids]).reject(&:blank?)
    typed_tag_names = permitted[:tag_list].to_s.split(",").map(&:strip).reject(&:blank?).uniq

    if typed_tag_names.any?
      created_tag_ids = typed_tag_names.map { |name| Tag.find_or_create_by!(name: name).id.to_s }
      permitted[:tag_ids] = (selected_tag_ids + created_tag_ids).uniq
    else
      permitted[:tag_ids] = selected_tag_ids
    end

    permitted.except(:tag_list)
  end

  def authorize_post!
    authorize @post
  end

  def authorize_admin!
    unless current_user&.admin?
      redirect_to posts_path, alert: 'Admin only.'
    end
  end
end
