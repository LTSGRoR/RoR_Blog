class Post < ApplicationRecord
  belongs_to :user
  enum :status, { draft: 0, published: 1 }
  validates :title, presence: true
  has_rich_text :body

  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }

  def verify!(admin)
    update!(verified: true, verified_at: Time.current, verified_by_id: admin.id)
  end

  def unverify!
    update!(verified: false, verified_at: nil, verified_by_id: nil)
  end

  def editable_by?(user)
    return true if user&.admin?
    !verified? && user == self.user
  end
end
