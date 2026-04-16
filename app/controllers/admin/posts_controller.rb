class Admin::PostsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize Post, :moderation_index?

    @query = params[:q].to_s.strip
    @filter = permitted_filter

    @pending_count = PostRevision.pending_review.count
    @draft_count = PostRevision.draft.count
    @reviewed_today_count = PostRevision.where(moderation_status: [PostRevision.moderation_statuses[:approved], PostRevision.moderation_statuses[:rejected]])
                                     .where("reviewed_at >= ?", Time.current.beginning_of_day)
                                     .count

    base_scope = case @filter
    when "pending"
      PostRevision.pending_review
    when "open"
      PostRevision.open_for_edit
    when "reviewed"
      PostRevision.where(moderation_status: [PostRevision.moderation_statuses[:approved], PostRevision.moderation_statuses[:rejected]])
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

    @revisions = @revisions.order(updated_at: :desc).page(params[:page]).per(20)
  end

  private

  def permitted_filter
    %w[pending open reviewed].include?(params[:filter]) ? params[:filter] : "pending"
  end
end