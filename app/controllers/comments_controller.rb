class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :ensure_interactions_enabled!

  def reply
    parent_comment = @post.comments.find(params[:id])
    open = params[:cancel].blank?
    render partial: "comments/reply_form",
           locals: { post: @post, parent_comment: parent_comment, comment: Comment.new, open: open }
  end

  def create
    @comment = @post.comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      if @comment.parent_id?
        parent_comment = @comment.parent
        @comment.broadcast_append_later_to(
          @post,
          target: helpers.dom_id(parent_comment, :replies),
          partial: "comments/comment",
          locals: { comment: @comment }
        )

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.append(
                helpers.dom_id(parent_comment, :replies),
                partial: "comments/comment",
                locals: { comment: @comment }
              ),
              turbo_stream.replace(
                helpers.dom_id(parent_comment, :reply_form),
                partial: "comments/reply_form",
                locals: { post: @post, parent_comment: parent_comment, comment: Comment.new, open: false }
              )
            ]
          end
          format.html { redirect_to @post, notice: "Reply posted." }
        end
      else
        @comment.broadcast_append_later_to(
          @post,
          target: helpers.dom_id(@post, :comments),
          partial: "comments/comment",
          locals: { comment: @comment }
        )

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.append(
                helpers.dom_id(@post, :comments),
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
      end
    else
      respond_to do |format|
        format.turbo_stream do
          if @comment.parent_id?
            parent_comment = Comment.find(@comment.parent_id)
            render turbo_stream: turbo_stream.replace(
              helpers.dom_id(parent_comment, :reply_form),
              partial: "comments/reply_form",
              locals: { post: @post, parent_comment: parent_comment, comment: @comment, open: true }
            ), status: :unprocessable_entity
          else
            render turbo_stream: turbo_stream.replace(
              "new_comment",
              partial: "comments/form",
              locals: { post: @post, comment: @comment }
            ), status: :unprocessable_entity
          end
        end
        format.html do
          redirect_to @post, alert: @comment.errors.full_messages.to_sentence
        end
      end
    end
  end

  private

  def set_post
    @post = Post.find_by(id: params[:post_id])
    unless @post
      redirect_to posts_path, alert: "Post not found." and return
    end
    authorize @post, :show?
  end

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end

  def ensure_interactions_enabled!
    return if @post.interactions_enabled?

    respond_to do |format|
      format.turbo_stream { head :forbidden }
      format.html { redirect_to @post, alert: "Comments are disabled for this post." }
    end
  end
end
