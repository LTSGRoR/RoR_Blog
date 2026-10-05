class ChatSessionsController < ApplicationController
  before_action :authenticate_user!
  rescue_from ChatSession::CreationLimitExceeded do
    response.set_header("Retry-After", "3600")
    render json: { error: t("shared.ai_chat.session_limit") }, status: :too_many_requests
  end

  def index
    sessions = current_user.chat_sessions.active.order(id: :desc)
    sessions = sessions.where("id < ?", params[:before].to_i) if params[:before].present?
    records = sessions.limit(21).to_a
    more = records.size > 20
    records = records.first(20)
    render json: { sessions: records.map { |session| session_data(session) }, before: more ? records.last.id : nil }
  end

  def show
    render json: session_data(current_user.chat_sessions.active.find(params[:id]))
  end

  def create
    session = ChatSession.create_for!(current_user)
    render json: session_data(session), status: :created
  end

  def destroy
    session = current_user.chat_sessions.active.find(params[:id])
    session.with_lock do
      session.clear_messages!
      session.update!(deleted_at: Time.current, title: nil)
    end
    head :no_content
  end

  private

  def session_data(session)
    { id: session.id, title: session.title.presence || t("shared.ai_chat.new_chat"),
      history_url: chat_history_path(chat_session_id: session.id),
      delete_url: chat_session_path(session) }
  end
end
