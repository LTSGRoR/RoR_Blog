class Admin::PostRevisionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_revision

  def show
    authorize @revision, :show?
  end

  def approve
    authorize @revision, :approve?
    @revision.approve!(admin: current_user, note: review_note)
    redirect_back fallback_location: admin_posts_path, notice: t("admin.posts.flash.approved")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: admin_posts_path, alert: e.message
  end

  def reject
    authorize @revision, :reject?
    @revision.reject!(admin: current_user, note: review_note)
    redirect_back fallback_location: admin_posts_path, notice: t("admin.posts.flash.rejected")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: admin_posts_path, alert: e.message
  end

  def destroy
    authorize @revision, :destroy?
    @revision.destroy!
    redirect_back fallback_location: admin_posts_path(scope: "revisions"), notice: t("admin.posts.flash.deleted")
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_back fallback_location: admin_posts_path(scope: "revisions"), alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_revision
    @revision = PostRevision.includes(:post, :author).find_by(id: params[:id])
    unless @revision
      redirect_to admin_posts_path, alert: "Revision not found." and return
    end
  end

  def review_note
    params.dig(:post_revision, :review_note).to_s
  end
end
