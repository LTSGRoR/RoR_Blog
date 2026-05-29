class ChatHistory < ApplicationRecord
  belongs_to :user
  belongs_to :post, optional: true

  validates :user_message, presence: true
  # `bot_response` is filled asynchronously by a background job, so we allow
  # records to be created without it and validate presence only on update if needed.

  scope :for_user, ->(user_id) { where(user_id: user_id) }
end
