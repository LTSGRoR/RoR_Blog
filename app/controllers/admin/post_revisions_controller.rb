class Admin::PostRevisionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_revision

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

  private

  def set_revision
    @revision = PostRevision.includes(:post, :author).find(params[:id])
  end

  def review_note
    params.dig(:post_revision, :review_note).to_s
  end
end