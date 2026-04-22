class ReactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_reactable
  before_action :ensure_interactions_enabled!

  def create
    emoji_type = reaction_params[:emoji_type]

    existing_reaction = current_user.reactions.find_by(reactable: @reactable)

    if existing_reaction&.emoji_type == emoji_type
      existing_reaction.destroy
    elsif existing_reaction
      existing_reaction.update!(emoji_type: emoji_type)
    else
      current_user.reactions.create!(reactable: @reactable, emoji_type: emoji_type)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          view_context.dom_id(@reactable, :reactions),
          partial: "reactions/bar",
          locals: { reactable: @reactable }
        )
      end
      format.html { redirect_back fallback_location: post_path(reactable_post) }
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          view_context.dom_id(@reactable, :reactions),
          partial: "reactions/bar",
          locals: { reactable: @reactable }
        ), status: :unprocessable_entity
      end
      format.html { redirect_back fallback_location: post_path(reactable_post), alert: e.message }
    end
  end

  private

  def set_reactable
    klass = params[:reactable_type].to_s.safe_constantize
    unless [ Post, Comment ].include?(klass)
      redirect_back fallback_location: posts_path, alert: "Invalid reaction target."
      return
    end

    @reactable = klass.find_by(id: params[:reactable_id])
    authorize reactable_post, :show?
  end

  def reaction_params
    params.require(:reaction).permit(:emoji_type)
  end

  def reactable_post
    @reactable.is_a?(Post) ? @reactable : @reactable.post
  end

  def ensure_interactions_enabled!
    return if reactable_post.interactions_enabled?

    respond_to do |format|
      format.turbo_stream { head :forbidden }
      format.html { redirect_to reactable_post, alert: "Reactions are disabled for this post." }
    end
  end
end
