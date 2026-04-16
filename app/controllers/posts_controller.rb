
class PostsController < ApplicationController
  before_action :set_post, only: %i[show edit update destroy verify unverify reply_feedback]
  before_action :authenticate_user!, only: %i[new create edit update destroy verify unverify reply_feedback]
  before_action :authorize_show!, only: %i[show]
  before_action :authorize_post!, only: %i[edit update destroy]
  before_action :authorize_verify!, only: %i[verify]
  before_action :authorize_unverify!, only: %i[unverify]
  before_action :authorize_feedback_reply!, only: %i[reply_feedback]

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
                { status: Post.statuses.key(Post.statuses[:published]) },
                { user_id: current_user.id }
              ]
            }
          elsif current_user
            {
              _or: [
                { status: Post.statuses.key(Post.statuses[:published]), verified: true },
                { user_id: current_user.id }
              ]
            }
          else
            { status: Post.statuses.key(Post.statuses[:published]), verified: true }
          end
          @posts = Post.search(
            query,
            fields: [ "title^5", "tags^3", "body" ],
            where: search_scope,
            page: @page,
            per_page: @per_page,
            operator: query.include?(" ") ? "and" : "or",
            misspellings: { below: 5 }
          )
          # Searchkick executes lazily; force execution here so errors are rescued in controller.
          @posts.total_count
        rescue StandardError => e
          Rails.logger.warn("Searchkick unavailable: #{e.class} - #{e.message}")
          @posts = Post.none.page(@page).per(@per_page)
        end
      else
        @posts = Post.none.page(@page).per(@per_page)
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
    @comments = @post.comments.includes(:user).order(created_at: :asc).page(params[:page]).per(10)
    @comment = Comment.new
    @active_revision = if current_user&.admin? || current_user == @post.user
      @post.active_revision
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
    redirect_to posts_url, notice: "Post was successfully destroyed."
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
      redirect_back fallback_location: @post, alert: "Reply is required."
      return
    end

    @post.reply_to_feedback!(author: current_user, reply: reply)
    redirect_back fallback_location: @post, notice: "Reply sent to admin feedback."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: @post, alert: e.message
  end

  private

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
end
