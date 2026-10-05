class ChatController < ApplicationController
  before_action :authenticate_user!
  before_action :set_post
  before_action :authorize_post!, if: -> { @post.present? }

  def index
    scope = current_user.chat_histories.visible.order(id: :desc)
    scope = scope.where("id < ?", params[:before].to_i) if params[:before].present?
    histories = scope.limit(21).to_a
    more = histories.size > 20
    histories = histories.first(20)
    posts = ChatHistory.suggestion_map(histories)
    html = histories.reverse.map do |history|
      render_to_string(partial: "chat_histories/chat_history_item",
        locals: { chat_history: history, suggestion_map: posts }, formats: [ :html ])
    end.join
    render json: { html: html, before: more ? histories.last.id : nil }
  end

  def clear_history
    # Retain usage timestamps so clearing cannot reset AI request quotas.
    current_user.chat_histories.visible.update_all(cleared_at: Time.current,
      user_message: "[cleared]", bot_response: "[cleared]", provider_meta: nil, embedding: nil)
    head :no_content
  end

  def create
    message = params[:message].to_s.strip
    return render json: { error: "Message cannot be blank" }, status: :unprocessable_entity if message.blank?

    chat = ChatHistory.accept_request!(user: current_user, post: @post, message: message)
    GeneratePostSuggestionJob.perform_later(chat.id)

    # Render the partial as HTML regardless of the incoming request format
    html = render_to_string(partial: "chat_histories/chat_history_item", locals: { chat_history: chat }, formats: [ :html ])
    render json: { id: chat.id, html: html, status_url: chat_status_path(chat) }, status: :accepted
  rescue ChatHistory::QuotaExceeded => e
    response.set_header("Retry-After", "600")
    render json: { error: e.message }, status: :too_many_requests
  end

  def show
    chat = current_user.chat_histories.visible.find_by(id: params[:id])
    return render json: { error: "Chat not found" }, status: :not_found unless chat

    return render json: { id: chat.id, ready: false } unless chat.bot_response.present?

    html = render_to_string(partial: "chat_histories/chat_history_item", locals: { chat_history: chat }, formats: [ :html ])
    render json: { id: chat.id, ready: chat.bot_response.present?, html: html }, status: :ok
  end

  private

  def set_post
    post_id = params[:post_id].presence || (params[:id].presence if action_name == "create")
    return unless post_id

    @post = Post.find_by(id: post_id)
    render json: { error: "Post not found" }, status: :not_found and return unless @post
  end

  def authorize_post!
    authorize @post, :show?
  end
end
