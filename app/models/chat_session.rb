class ChatSession < ApplicationRecord
  belongs_to :user
  has_many :chat_histories, dependent: :destroy
  scope :active, -> { where(deleted_at: nil) }
  validates :title, length: { maximum: 100 }

  def self.default_for(user)
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(741902002, #{Integer(user.id)})")
      user.chat_sessions.active.order(:id).first || user.chat_sessions.create!
    end
  end

  def clear_messages!
    chat_histories.visible.update_all(cleared_at: Time.current,
      user_message: "[cleared]", bot_response: "[cleared]", provider_meta: nil, embedding: nil)
  end
end
