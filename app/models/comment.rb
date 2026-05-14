class Comment < ApplicationRecord
  MAX_REPLY_DEPTH = 5
  DEFAULT_VISIBLE_REPLY_DEPTH = 1
  MAX_VISIBLE_REPLY_DEPTH = 10

  belongs_to :post
  belongs_to :user
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :reactions, as: :reactable, dependent: :destroy

  scope :root, -> { where(parent_id: nil) }

  validates :body, presence: true
  validate :parent_belongs_to_same_post, if: :parent_id?
  validate :within_max_reply_depth, if: :parent_id?

  def depth
    level = 0
    node = self

    while node.parent_id
      level += 1
      node = node.parent
      break unless node
    end

    level
  end

  private

  def parent_belongs_to_same_post
    errors.add(:parent, "must belong to the same post") if parent && parent.post_id != post_id
  end

  def within_max_reply_depth
    return unless parent

    if parent.depth >= MAX_REPLY_DEPTH
      errors.add(:parent, "maximum reply depth is #{MAX_REPLY_DEPTH}")
    end
  end
end
