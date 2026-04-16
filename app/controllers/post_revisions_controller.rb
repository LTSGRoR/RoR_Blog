class PostRevisionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :set_or_build_revision, only: %i[new create]
  before_action :set_revision, only: %i[edit update submit]

  def new
    authorize @revision
  end

  def create
    authorize @revision
    @revision.assign_attributes(revision_params)
    apply_revision_tag_names(@revision)

    if @revision.save
      redirect_to edit_post_revision_path(@post), notice: t("post_revisions.flash.saved")
    else
      flash.now[:alert] = @revision.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @revision
  end

  def update
    authorize @revision
    @revision.assign_attributes(revision_params)
    apply_revision_tag_names(@revision)

    if @revision.save
      redirect_to edit_post_revision_path(@post), notice: t("post_revisions.flash.saved")
    else
      flash.now[:alert] = @revision.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def submit
    authorize @revision, :submit?
    @revision.submit!
    redirect_to @post, notice: t("post_revisions.flash.submitted")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to edit_post_revision_path(@post), alert: e.message
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
    authorize @post, :request_revision?
  end

  def set_or_build_revision
    @revision = @post.active_revision
    return if @revision.present?

    @revision = @post.post_revisions.build(author: current_user, title: @post.title)
    @revision.body = @post.body.to_s
    @revision.tags = @post.tags
  end

  def set_revision
    @revision = @post.active_revision
    return if @revision.present?

    redirect_to new_post_revision_path(@post), alert: t("post_revisions.flash.start_first")
  end

  def revision_params
    params.require(:post_revision).permit(:title, :body, :tag_list)
  end

  def apply_revision_tag_names(revision)
    tag_names = params.dig(:post_revision, :tag_list).to_s.split(",").map(&:strip).reject(&:blank?).uniq
    revision.tags = tag_names.map { |name| Tag.find_or_create_by!(name: name) }
  end
end