class ChatHistory < ApplicationRecord
  belongs_to :user
  belongs_to :post, optional: true

  validates :user_message, presence: true
  validates :bot_response, presence: true

  scope :for_user, ->(user_id) { where(user_id: user_id) }
end
