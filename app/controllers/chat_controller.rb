class ChatController < ApplicationController
  before_action :authenticate_user!
  rescue_from ChatSession::CreationLimitExceeded do
    response.set_header("Retry-After", "3600")
    render json: { error: t("shared.ai_chat.session_limit") }, status: :too_many_requests
  end
  before_action :set_chat_session, only: [ :index, :create, :clear_history ]
  before_action :set_post
  before_action :authorize_post!, if: -> { @post.present? }

  def index
    scope = @chat_session.chat_histories.visible.order(id: :desc)
    scope = scope.where("id < ?", params[:before].to_i) if params[:before].present?
    histories = scope.limit(21).to_a
    more = histories.size > 20
    histories = histories.first(20)
    posts = ChatHistory.suggestion_map(histories)
    html = histories.reverse.map do |history|
      render_to_string(partial: "chat_histories/chat_history_item",
        locals: { chat_history: history, suggestion_map: posts }, formats: [ :html ])
    end.join
    pending = @chat_session.chat_histories.visible.where(bot_response: nil, created_at: ChatHistory::REQUEST_TTL.ago..).order(id: :desc).first
    render json: { html: html, before: more ? histories.last.id : nil,
      pending: pending ? { id: pending.id, status_url: chat_status_path(pending) } : nil }
  end

  def clear_history
    @chat_session.with_lock { @chat_session.clear_messages! }
    head :no_content
  end

  def create
    message = params[:message].to_s.strip
    return render json: { error: t("shared.ai_chat.message_blank") }, status: :unprocessable_entity if message.blank?

    chat = ChatHistory.accept_request!(user: current_user, post: @post, message: message, chat_session: @chat_session)
    GeneratePostSuggestionJob.perform_later(chat.id, I18n.locale.to_s)

    # Render the partial as HTML regardless of the incoming request format
    html = render_to_string(partial: "chat_histories/chat_history_item", locals: { chat_history: chat }, formats: [ :html ])
    render json: { id: chat.id, html: html, status_url: chat_status_path(chat), session_title: @chat_session.reload.title }, status: :accepted
  rescue ChatHistory::QuotaExceeded
    response.set_header("Retry-After", "600")
    render json: { error: t("shared.ai_chat.request_limit") }, status: :too_many_requests
  end

  def show
    chat = current_user.chat_histories.visible.find_by(id: params[:id])
    return render json: { error: t("shared.ai_chat.chat_missing") }, status: :not_found unless chat

    return render json: { id: chat.id, ready: false } unless chat.bot_response.present?

    html = render_to_string(partial: "chat_histories/chat_history_item", locals: { chat_history: chat }, formats: [ :html ])
    render json: { id: chat.id, ready: chat.bot_response.present?, html: html }, status: :ok
  end

  private

  def set_chat_session
    @chat_session = if params[:chat_session_id].present?
      current_user.chat_sessions.active.find(params[:chat_session_id])
    else
      ChatSession.default_for(current_user)
    end
  end

  def set_post
    post_id = params[:post_id].presence || (params[:id].presence if action_name == "create")
    return unless post_id

    @post = Post.find_by(id: post_id)
    render json: { error: t("shared.ai_chat.post_missing") }, status: :not_found and return unless @post
  end

  def authorize_post!
    authorize @post, :show?
  end
end
