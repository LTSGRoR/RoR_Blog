class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :ensure_interactions_enabled!

  def create
    @comment = @post.comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append(
              "comments_list",
              partial: "comments/comment",
              locals: { comment: @comment }
            ),
            turbo_stream.replace(
              "new_comment",
              partial: "comments/form",
              locals: { post: @post, comment: Comment.new }
            )
          ]
        end
        format.html { redirect_to @post, notice: "Comment posted." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "new_comment",
            partial: "comments/form",
            locals: { post: @post, comment: @comment }
          ), status: :unprocessable_entity
        end
        format.html do
          redirect_to @post, alert: @comment.errors.full_messages.to_sentence
        end
      end
    end
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
    authorize @post, :show?
  end

  def comment_params
    params.require(:comment).permit(:body)
  end

  def ensure_interactions_enabled!
    return if @post.interactions_enabled?

    respond_to do |format|
      format.turbo_stream { head :forbidden }
      format.html { redirect_to @post, alert: "Comments are disabled for this post." }
    end
  end
end
