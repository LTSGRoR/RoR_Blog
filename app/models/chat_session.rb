class ChatSession < ApplicationRecord
  belongs_to :user
  has_many :chat_histories, dependent: :destroy
  scope :active, -> { where(deleted_at: nil) }
  validates :title, length: { maximum: 100 }

  CREATION_HOURLY_LIMIT = 30
  class CreationLimitExceeded < StandardError; end

  def self.create_for!(user)
    transaction do
      connection.execute(sanitize_sql_array([ "SELECT pg_advisory_xact_lock(741902002, ?)", Integer(user.id) ]))
      raise CreationLimitExceeded if user.chat_sessions.where(created_at: 1.hour.ago..).count >= CREATION_HOURLY_LIMIT

      # Only remove old deleted conversations that never contained messages.
      unused_ids = user.chat_sessions.where(deleted_at: ..30.days.ago)
                       .where.not(id: ChatHistory.select(:chat_session_id)).limit(100).pluck(:id)
      user.chat_sessions.where(id: unused_ids).delete_all
      user.chat_sessions.create!
    end
  end

  def self.default_for(user)
    transaction do
      connection.execute(sanitize_sql_array([ "SELECT pg_advisory_xact_lock(741902002, ?)", Integer(user.id) ]))
      user.chat_sessions.active.order(:id).first || create_for!(user)
    end
  end

  def clear_messages!
    chat_histories.visible.update_all(cleared_at: Time.current,
      user_message: "[cleared]", bot_response: "[cleared]", provider_meta: nil, embedding: nil)
  end
end
