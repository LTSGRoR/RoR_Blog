class PostRevisionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :set_or_build_revision, only: %i[new create]
  before_action :set_revision, only: %i[edit update submit withdraw]
  before_action :set_feedback_revision, only: %i[new create edit update]

  def new
    authorize @revision
  end

  def create
    authorize @revision
    # Process explicit remove flag before assigning attributes so an incoming
    # `thumbnail` param can't re-attach after we've purged it.
    remove_flag = params.dig(:post_revision, :remove_thumbnail).to_s == "1"
    attrs = revision_params.to_h
    if remove_flag
      attrs.delete(:thumbnail)
      attrs.delete("thumbnail")
      @revision.thumbnail.purge if @revision.thumbnail.attached?
    end

    @revision.assign_attributes(attrs)
    apply_revision_tags(@revision)

    if submit_for_review_request?
      @revision.submit!
    else
      @revision.prepare_as_draft!
    end

    if @revision.save
      if submit_for_review_request?
        enqueue_ai_review_for(@revision)
        redirect_to @post, notice: t("post_revisions.flash.submitted")
      else
        redirect_to edit_post_revision_path(@post), notice: t("post_revisions.flash.saved")
      end
    else
      flash.now[:alert] = @revision.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @revision
  end

  def update
    authorize @revision
    # Process explicit remove flag before assigning attributes so an incoming
    # `thumbnail` param can't re-attach after we've purged it.
    remove_flag = params.dig(:post_revision, :remove_thumbnail).to_s == "1"
    attrs = revision_params.to_h
    if remove_flag
      attrs.delete(:thumbnail)
      attrs.delete("thumbnail")
      @revision.thumbnail.purge if @revision.thumbnail.attached?
    end

    @revision.assign_attributes(attrs)
    apply_revision_tags(@revision)

    if submit_for_review_request?
      @revision.submit!
    else
      @revision.prepare_as_draft!
    end

    if @revision.save
      if submit_for_review_request?
        enqueue_ai_review_for(@revision)
        redirect_to @post, notice: t("post_revisions.flash.submitted")
      else
        redirect_to edit_post_revision_path(@post), notice: t("post_revisions.flash.saved")
      end
    else
      flash.now[:alert] = @revision.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_entity
  end

  def submit
    authorize @revision, :submit?
    @revision.submit!
    enqueue_ai_review_for(@revision)
    redirect_to @post, notice: t("post_revisions.flash.submitted")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to edit_post_revision_path(@post), alert: e.message
  end

  def withdraw
    authorize @revision, :withdraw?
    @revision.prepare_as_draft!
    @revision.save!
    redirect_to edit_post_revision_path(@post), notice: t("post_revisions.flash.withdrawn")
  end

  private

  def set_post
    @post = Post.find_by(id: params[:post_id])
    unless @post
      redirect_to posts_path, alert: "Post not found." and return
    end
    authorize @post, :request_revision?
  end

  def set_or_build_revision
    @revision = @post.active_revision
    return if @revision.present?

    seed_revision = latest_rejected_revision
    @revision = @post.post_revisions.build(author: current_user, title: seed_revision&.title || @post.title)
    @revision.body = seed_revision&.body&.to_s || @post.body.to_s
    @revision.tags = seed_revision&.tags || @post.tags
    # Copy thumbnail from the seed revision if available; otherwise copy the
    # live post's thumbnail so the editor shows the current post image by default.
    if seed_revision&.thumbnail&.attached?
      @revision.thumbnail.attach(seed_revision.thumbnail.blob)
    elsif @post.thumbnail&.attached?
      @revision.thumbnail.attach(@post.thumbnail.blob)
    end
  end

  def set_revision
    @revision = @post.active_revision
    return if @revision.present?

    redirect_to new_post_revision_path(@post), alert: t("post_revisions.flash.start_first")
  end

  def set_feedback_revision
    return unless current_user == @post.user

    rejected_revision = latest_rejected_revision
    return if rejected_revision.blank?
    return unless @revision.new_record? || @revision.draft?

    @feedback_revision = rejected_revision
  end

  def revision_params
    params.require(:post_revision).permit(:title, :body, :thumbnail)
  end

  def apply_revision_tags(revision)
    selected_tag_ids = Array(params.dig(:post_revision, :tag_ids)).reject(&:blank?)
    typed_tag_names = params.dig(:post_revision, :tag_list).to_s.split(",").map(&:strip).reject(&:blank?).uniq

    created_tag_ids = typed_tag_names.map { |name| Tag.find_or_create_by!(name: name).id.to_s }
    tag_ids = (selected_tag_ids + created_tag_ids).uniq

    revision.tags = Tag.where(id: tag_ids)
  end

  def submit_for_review_request?
    params[:commit_action] == "submit_for_review"
  end

  def latest_rejected_revision
    @latest_rejected_revision ||= @post.post_revisions.rejected.where(author_id: current_user.id).order(reviewed_at: :desc, updated_at: :desc).first
  end

  def enqueue_ai_review_for(revision)
    return unless ai_auto_review_enabled?
    return unless revision.pending_review?

    revision.queue_ai_review!
    ModeratePostRevisionJob.perform_later(revision.id)
  end

  def ai_auto_review_enabled?
    AiModeration::Configuration.current.fetch(:auto_review_enabled)
  end
end
