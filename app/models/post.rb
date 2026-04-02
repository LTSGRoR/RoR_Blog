class Post < ApplicationRecord
  searchkick word_middle: [:title, :tags], callbacks: :async

  belongs_to :user
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings
  enum :status, { draft: 0, published: 1 }
  validates :title, presence: true
  has_rich_text :body

  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }

  def verify!(admin)
    raise "Cannot verify draft posts" unless published?
    update!(verified: true, verified_at: Time.current, verified_by_id: admin.id)
  end

  def unverify!
    update!(verified: false, verified_at: nil, verified_by_id: nil)
  end

  def editable_by?(user)
    return true if user&.admin?
    !verified? && user == self.user
  end

  def search_data
    {
      title: title,
      body: body.to_plain_text,
      tags: tags.map(&:name),
      status: status,
      verified: verified
    }
  end

  def tag_list
    tags.pluck(:name).join(', ')
  end
end
