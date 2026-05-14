class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :reactions, as: :reactable, dependent: :destroy

  scope :root, -> { where(parent_id: nil) }

  validates :body, presence: true
  validate :parent_belongs_to_same_post, if: :parent_id?

  private

  def parent_belongs_to_same_post
    errors.add(:parent, "must belong to the same post") if parent && parent.post_id != post_id
  end
end
