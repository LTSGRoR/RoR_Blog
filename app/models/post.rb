  class Post < ApplicationRecord
    belongs_to :user
    has_many :taggings, dependent: :destroy
    has_many :tags, through: :taggings
    enum :status, { draft: 0, published: 1 }
    validates :title, presence: true
    has_rich_text :body
    # searchkick word_middle: [:title, :tags], callbacks: :async

  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }

  def verify!(admin)
    raise "Cannot verify draft posts" unless published?
    update!(verified: true, verified_at: Time.current, verified_by_id: admin.id)
  end

    scope :verified, -> { where(verified: true) }
    scope :unverified, -> { where(verified: false) }

    def verify!(admin)
      update!(verified: true, verified_at: Time.current, verified_by_id: admin.id)
    end

    def unverify!
      update!(verified: false, verified_at: nil, verified_by_id: nil)
    end

  def tag_list
    tags.pluck(:name).join(', ')
  end
end
