class ChatController < ApplicationController
  before_action :set_post
  before_action :authenticate_user!
  before_action :authorize_post!

  def create
    message = params[:message].to_s.strip
    if message.blank?
      render json: { error: "Message cannot be blank" }, status: :unprocessable_entity
      return
    end

    chat = ChatHistory.create!(user: current_user, post: @post, user_message: message)
    GeneratePostSuggestionJob.perform_later(chat.id)

    render json: { id: chat.id }, status: :accepted
  end

  private

  def set_post
    post_id = params[:post_id] || params[:id]
    @post = Post.find_by(id: post_id)
    render json: { error: "Post not found" }, status: :not_found unless @post
  end

  def authorize_post!
    authorize @post
  end
end
