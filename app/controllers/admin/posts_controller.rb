class Admin::PostsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize Post, :moderation_index?

    @query = params[:q].to_s.strip
    @scope = permitted_scope
    @filter = permitted_filter

    pending_posts_scope = Post.includes(:user, :tags)
                  .where(status: Post.statuses[:published], verified: false)
                  .order(created_at: :desc)

    published_posts_scope = Post.includes(:user, :tags)
                   .where(status: Post.statuses[:published])
                   .order(updated_at: :desc)

    @pending_count = PostRevision.pending_review.count
    @pending_post_count = pending_posts_scope.count
    @draft_count = PostRevision.draft.count
    @reviewed_today_count = PostRevision.where(moderation_status: [ PostRevision.moderation_statuses[:approved], PostRevision.moderation_statuses[:rejected] ])
                                     .where(reviewed_at: Time.current.beginning_of_day..)
                                     .count

    @pending_posts = if @query.present?
      published_posts_scope.joins(:user)
                           .where(
                             "posts.title ILIKE :q OR users.name ILIKE :q OR users.email ILIKE :q",
                             q: "%#{@query}%"
                           )
    else
      published_posts_scope
    end

    @pending_posts = @pending_posts.page(params[:posts_page]).per(10)

    base_scope = case @filter
    when "pending"
      PostRevision.pending_review
    when "open"
      PostRevision.open_for_edit
    when "reviewed"
      PostRevision.where(moderation_status: [ PostRevision.moderation_statuses[:approved], PostRevision.moderation_statuses[:rejected] ])
                  .where.not(reviewed_at: nil)
                  .order(reviewed_at: :desc)
    else
      PostRevision.pending_review
    end

    @revisions = base_scope.includes(:post, :author, :reviewer)

    if @query.present?
      @revisions = @revisions.joins(:post, :author)
                             .where(
                               "posts.title ILIKE :q OR users.name ILIKE :q OR users.email ILIKE :q",
                               q: "%#{@query}%"
                             )
    end

    @revisions = @revisions.order(updated_at: :desc).page(params[:revisions_page]).per(10)
  end

  private

  def permitted_scope
    %w[all posts revisions].include?(params[:scope]) ? params[:scope] : "all"
  end

  def permitted_filter
    %w[pending open reviewed].include?(params[:filter]) ? params[:filter] : "pending"
  end
end
