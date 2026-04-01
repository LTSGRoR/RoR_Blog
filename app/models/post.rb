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

  def tag_list=(names)
    @tag_list = names
  end

  after_save do
    if defined?(@tag_list) && @tag_list
      new_tags = @tag_list.to_s.split(',').map(&:strip).reject(&:blank?).uniq
      self.tags = new_tags.map { |n| Tag.find_or_create_by!(name: n) }
      @tag_list = nil
    end
  end
end
