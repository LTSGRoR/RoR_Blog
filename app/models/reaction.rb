class Reaction < ApplicationRecord
  EMOJI_MAP = {
    "thumbs_up" => "👍",
    "heart"     => "❤️",
    "laugh"     => "😂",
    "wow"       => "😮",
    "sad"       => "😢",
    "angry"     => "😠"
  }.freeze

  belongs_to :user
  belongs_to :reactable, polymorphic: true

  enum :emoji_type, { thumbs_up: 0, heart: 1, laugh: 2, wow: 3, sad: 4, angry: 5 }

  validates :emoji_type, presence: true
  validates :user_id, uniqueness: {
    scope: [ :reactable_type, :reactable_id ],
    message: "already reacted to this item"
  }
end
