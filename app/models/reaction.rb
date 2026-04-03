class Reaction < ApplicationRecord
  EMOJI_TYPES = [ "👍", "🚀", "❤️" ].freeze

  belongs_to :user
  belongs_to :reactable, polymorphic: true

  validates :emoji_type, presence: true, inclusion: { in: EMOJI_TYPES }
  validates :user_id, uniqueness: {
    scope: [ :reactable_type, :reactable_id ],
    message: "already reacted to this item"
  }
end
