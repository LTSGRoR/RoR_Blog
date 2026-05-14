class Reaction < ApplicationRecord
  EMOJI_MAP = {
    "thumbs_up"   => "👍",
    "thumbs_down" => "👎",
    "heart"       => "❤️",
    "cry"         => "😢",
    "laugh"       => "😂",
    "fire"        => "🔥"
  }.freeze

  belongs_to :user
  belongs_to :reactable, polymorphic: true

  enum :emoji_type, { thumbs_up: 0, cry: 1, heart: 2, thumbs_down: 3, laugh: 4, fire: 5 }

  validates :emoji_type, presence: true
  validates :user_id, uniqueness: {
    scope: [ :reactable_type, :reactable_id ],
    message: "already reacted to this item"
  }
end
