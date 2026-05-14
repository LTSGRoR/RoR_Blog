class PostsController < ApplicationController
  before_action :set_post, only: %i[show edit update destroy verify unverify reply_feedback]
  before_action :authenticate_user!, only: %i[new create edit update destroy verify unverify reply_feedback mine]
  before_action :authorize_show!, only: %i[show]
  before_action :authorize_post!, only: %i[edit update destroy]
  before_action :authorize_verify!, only: %i[verify]
  before_action :authorize_unverify!, only: %i[unverify]
  before_action :authorize_feedback_reply!, only: %i[reply_feedback]

  def index
    load_public_posts
    respond_with_posts
  end

  def mine
    @query = params[:q].to_s.strip
    @filter = params[:filter].presence_in(%w[all draft awaiting published]) || "all"
    base_posts = current_user.posts.includes(:tags, :post_revisions).order(updated_at: :desc)

    if @query.present?
      lowered_query = "%#{@query.downcase}%"
      base_posts = base_posts.left_outer_joins(:tags).where(
        "LOWER(posts.title) LIKE :query OR LOWER(tags.name) LIKE :query",
        query: lowered_query
      ).distinct
    end

    @draft_posts_count = base_posts.where(status: Post.statuses[:draft]).count
    @needs_review_posts_count = base_posts.where(status: Post.statuses[:published], verified: false).count
    @published_posts_count = base_posts.where(status: Post.statuses[:published], verified: true).count

    @posts = case @filter
    when "draft"
      base_posts.where(status: Post.statuses[:draft])
    when "awaiting"
      base_posts.where(status: Post.statuses[:published], verified: false)
    when "published"
      base_posts.where(status: Post.statuses[:published], verified: true)
    else
      base_posts
    end

    @posts = @posts.page(params[:page]).per(10)
  end

  def show
    requested_visible_count = params[:comments_visible].to_i
    @comments_visible = requested_visible_count.positive? ? requested_visible_count : 5
    @comments_increment = 10

    root_comments_scope = @post.comments.root.includes(:user, replies: :user).order(created_at: :asc)
    @root_comments_count = root_comments_scope.count
    @has_more_comments = @root_comments_count > @comments_visible
    @comments = root_comments_scope.limit(@comments_visible)

    @comment = Comment.new
    @active_revision = if current_user == @post.user
      @post.active_revision
    end
    @rejected_revision = if current_user == @post.user && @active_revision.nil?
      @post.post_revisions.rejected.where(author_id: current_user.id).order(reviewed_at: :desc).first
    end
  end

  def new
    @post = Post.new
    authorize @post
  end

  def edit
  end

  def update
    if @post.update(post_params)
      enqueue_ai_review_for(@post)
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
      enqueue_ai_review_for(@post)
      redirect_to @post, notice: "Post was successfully created."
    else
      flash.now[:alert] = @post.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_back fallback_location: mine_posts_path, notice: "Post was successfully destroyed."
  end

  def verify
    unless @post.published?
      redirect_back fallback_location: posts_path, alert: "Only published posts can be verified."
      return
    end
    @post.verify!(current_user)
    redirect_back fallback_location: posts_path, notice: "Post has been verified."
  end

  def unverify
    unless @post.published?
      redirect_back fallback_location: posts_path, alert: "Only published posts can receive admin feedback."
      return
    end

    reason = params.dig(:post, :unverify_reason).to_s.strip

    if reason.blank?
      redirect_back fallback_location: posts_path, alert: "Reason is required to unverify a post."
      return
    end

    was_verified = @post.verified?
    @post.unverify!(admin: current_user, reason: reason)
    notice_message = was_verified ? "Post has been unverified." : "Admin feedback has been saved."
    redirect_back fallback_location: posts_path, notice: notice_message
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: posts_path, alert: e.message
  end

  def reply_feedback
    reply = params.dig(:post, :author_feedback_reply).to_s.strip

    if reply.blank?
      redirect_back fallback_location: mine_posts_path, alert: "Reply is required."
      return
    end

    @post.reply_to_feedback!(author: current_user, reply: reply)
    redirect_back fallback_location: mine_posts_path, notice: "Reply sent to admin feedback."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: mine_posts_path, alert: e.message
  end

  private

  def load_public_posts
    @page = params[:page] || 1
    @per_page = 10
    @search_path = posts_path
    public_scope = Post.where(status: Post.statuses[:published], verified: true)

    if params[:q].present?
      query = params[:q].to_s.strip
      if defined?(Searchkick)
        begin
          search_scope = { status: Post.statuses.key(Post.statuses[:published]), verified: true }
          @posts = Post.search(
            query,
            fields: [ "title^5", "tags^3", "body" ],
            where: search_scope,
            page: @page,
            per_page: @per_page,
            operator: query.include?(" ") ? "and" : "or",
            misspellings: { below: 5 }
          )
          @posts.total_count
        rescue StandardError => e
          Rails.logger.warn("Searchkick unavailable: #{e.class} - #{e.message}")
          @posts = Post.none.page(@page).per(@per_page)
        end
      else
        @posts = Post.none.page(@page).per(@per_page)
      end
    else
      @posts = public_scope.includes(:tags).order(created_at: :desc).page(@page).per(@per_page)
    end
  end

  def respond_with_posts
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

  def set_post
    @post = Post.find_by(id: params[:id])
    unless @post
      redirect_to posts_path, alert: "Post not found."
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

  def authorize_show!
    authorize @post, :show?
  end

  def authorize_verify!
    authorize @post, :verify?
  end

  def authorize_unverify!
    authorize @post, :unverify?
  end

  def authorize_feedback_reply!
    unless current_user == @post.user
      redirect_to @post, alert: "Only the post author can reply to feedback."
    end
  end

  def enqueue_ai_review_for(post)
    return unless ai_auto_review_enabled?
    return unless post.published?
    return if post.verified?

    post.queue_ai_review!
    ModeratePostJob.perform_later(post.id)
  end

  def ai_auto_review_enabled?
    AiModeration::Configuration.current.fetch(:auto_review_enabled)
  end
end
