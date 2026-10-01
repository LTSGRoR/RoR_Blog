class Admin::PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post, only: :rerun_ai_review

  def index
    authorize Post, :moderation_index?

    @query = params[:q].to_s.strip
    @scope = permitted_scope
    @filter = normalized_filter(scope: @scope, filter: permitted_filter)

    published_posts_scope = Post.includes(:user, :tags)
                   .where(status: Post.statuses[:published])
                   .order(updated_at: :desc)

    load_review_queue_stats

    pending_by_reviewer = PostRevision.pending_review.group(:reviewer_id).count
    @pending_revisions_by_reviewer = pending_revisions_by_reviewer(pending_by_reviewer)

    @pending_posts = if @query.present?
      published_posts_scope.joins(:user)
                           .where(
                             "posts.title ILIKE :q OR users.name ILIKE :q OR users.email ILIKE :q",
                             q: "%#{@query}%"
                           )
    else
      published_posts_scope
    end

    @pending_posts = case @filter
    when "awaiting_review"
      @pending_posts.where(verified: false, unverify_reason: nil)
    when "rejected"
      @pending_posts.where.not(unverify_reason: nil)
    when "ai_needs_admin_review"
      @pending_posts.where(ai_review_status: Post.ai_review_statuses[:needs_admin_review])
    when "ai_auto_approved"
      @pending_posts.where(ai_review_status: Post.ai_review_statuses[:auto_approved])
    when "ai_failed"
      @pending_posts.where(ai_review_status: Post.ai_review_statuses[:failed])
    when "ai_pending"
      @pending_posts.where(ai_review_status: Post.ai_review_statuses[:pending])
    else
      @pending_posts
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

  def rerun_ai_review
    authorize Post, :moderation_index?

    unless rerunnable_ai_review?(@post)
      redirect_back fallback_location: admin_posts_path(locale: I18n.locale), alert: t("admin.posts.flash.rerun_not_allowed")
      return
    end

    @post.queue_ai_review!
    ModeratePostJob.perform_later(@post.id)

    redirect_back fallback_location: admin_posts_path(locale: I18n.locale), notice: t("admin.posts.flash.rerun_enqueued")
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: admin_posts_path(locale: I18n.locale), alert: e.message
  end

  private

  # The dashboard renders six queue counters. Each bucket used to run its own
  # COUNT; FILTER aggregates keep the exact same predicates but collapse each
  # table's counters into a single round trip.
  def load_review_queue_stats
    day_start = Post.connection.quote(Time.current.beginning_of_day)
    published_status = Post.statuses[:published].to_i

    @pending_post_count, @new_post_count, @awaiting_review_count, @verified_today_count = Post.pick(
      Arel.sql("COUNT(*) FILTER (WHERE status = #{published_status} AND verified = FALSE)"),
      Arel.sql("COUNT(*) FILTER (WHERE created_at >= #{day_start})"),
      Arel.sql("COUNT(*) FILTER (WHERE status = #{published_status} AND verified = FALSE AND unverify_reason IS NULL)"),
      Arel.sql("COUNT(*) FILTER (WHERE verified = TRUE AND verified_at >= #{day_start})")
    )

    pending_review_status = PostRevision.moderation_statuses[:pending_review].to_i
    draft_status = PostRevision.moderation_statuses[:draft].to_i
    approved_status = PostRevision.moderation_statuses[:approved].to_i
    rejected_status = PostRevision.moderation_statuses[:rejected].to_i

    @pending_count, @draft_count, @reviewed_today_count = PostRevision.pick(
      Arel.sql("COUNT(*) FILTER (WHERE moderation_status = #{pending_review_status})"),
      Arel.sql("COUNT(*) FILTER (WHERE moderation_status = #{draft_status})"),
      Arel.sql("COUNT(*) FILTER (WHERE moderation_status IN (#{approved_status}, #{rejected_status}) " \
               "AND reviewed_at >= #{day_start})")
    )
  end

  # Reviewer names for the queue chips used to be one User.find_by per reviewer.
  def pending_revisions_by_reviewer(pending_by_reviewer)
    reviewer_ids = pending_by_reviewer.keys.compact
    reviewer_names = reviewer_ids.empty? ? {} : User.where(id: reviewer_ids).pluck(:id, :name).to_h

    pending_by_reviewer.map do |reviewer_id, count|
      name = if reviewer_id.present?
        reviewer_names[reviewer_id].presence || "User ##{reviewer_id}"
      else
        I18n.t("admin.posts.index.stats.unassigned")
      end
      { reviewer: name, count: count }
    end
  end

  def set_post
    @post = Post.find(params[:id])
  end

  def rerunnable_ai_review?(post)
    post.published? && !post.verified? && post.ai_review_failed?
  end

  def permitted_scope
    %w[all posts revisions].include?(params[:scope]) ? params[:scope] : "posts"
  end

  def permitted_filter
    allowed = %w[
      all_posts
      awaiting_review
      rejected
      ai_needs_admin_review
      ai_auto_approved
      ai_failed
      ai_pending
      pending
      open
      reviewed
    ]

    allowed.include?(params[:filter]) ? params[:filter] : nil
  end

  def normalized_filter(scope:, filter:)
    case scope
    when "posts"
      %w[
        all_posts
        awaiting_review
        rejected
        ai_needs_admin_review
        ai_auto_approved
        ai_failed
        ai_pending
      ].include?(filter) ? filter : "all_posts"
    else
      %w[pending open reviewed].include?(filter) ? filter : "pending"
    end
  end
end
