class ChatController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :authorize_post!, if: -> { @post.present? }

  def create
    message = params[:message].to_s.strip
    return render json: { error: "Message cannot be blank" }, status: :unprocessable_entity if message.blank?

    chat = ChatHistory.create!(user: current_user, post: @post, user_message: message)
    GeneratePostSuggestionJob.perform_later(chat.id)

    # Render the partial as HTML regardless of the incoming request format
    html = render_to_string(partial: "chat_histories/chat_history_item", locals: { chat_history: chat }, formats: [ :html ])
    render json: { id: chat.id, html: html, status_url: chat_status_path(chat) }, status: :accepted
  end

  def show
    chat = current_user.chat_histories.find_by(id: params[:id])
    return render json: { error: "Chat not found" }, status: :not_found unless chat

    html = render_to_string(partial: "chat_histories/chat_history_item", locals: { chat_history: chat }, formats: [ :html ])
    render json: { id: chat.id, ready: chat.bot_response.present?, html: html }, status: :ok
  end

  private

  def set_post
    return unless params[:post_id].present?
    @post = Post.find_by(id: params[:post_id])
    render json: { error: "Post not found" }, status: :not_found unless @post
  end

  def authorize_post!
    authorize @post
  end
end
